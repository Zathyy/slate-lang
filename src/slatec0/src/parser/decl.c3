module slate::parser;

import slate::core;
import slate::lexer;

import std::collections;

<*
 @require ctx.current.kind == MODULE
*>
fn Node* parse_module_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_module_decl");

	advance(ctx);

	ModuleDecl* node = ctx.ast.alloc_node(ModuleDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;
	node.path = parse_path(ctx);

	if (!node.path)
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected a valid path");
		node.flags.has_error = true;
		return (Node*)node;
	}

	if (ctx.is(LESS))
	{
		//node.generics = parse_generic_decl(scope);
	}

	expect(ctx, node, EOS);

	PathAtom* path = node.path.as(PathAtom);
	String mod_name = path.path.text;

	return (Node*)node;
}

<*
 @require ctx.current.kind == IMPORT
*>
fn Node* parse_import_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	advance(ctx);
	ImportDecl* node = ctx.ast.alloc_node(ImportDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;
	List{Node*} temp_paths;
	temp_paths.init(tmem, 4);

	while (!ctx.eof())
	{
		Node* path_node = parse_path(ctx);
		temp_paths.push(path_node);

		if (path_node.kind == ERROR)
		{
			node.flags.has_error = true;
		}

		if (!consume(ctx, COMMA)) break;
		if (ctx.is(EOS))
		{
			diagnostics::error(ctx.context, ctx.current.range, "Expected another path after ','");
			node.flags.has_error = true;
			break;
		}
	}

	node.paths = alloc::clone_slice(ctx.allocator, temp_paths.array_view());

	expect(ctx, node, EOS);

	return (Node*)node;
}

<*
 @require ctx.current.kind == LBRACKET
*>
fn NodeArray parse_attributes(ParseContext* ctx) => @pool()
{
    diagnostics::log_debug("parse_attributes");

    List{Node*} attrs;
    attrs.tinit();

    // Outer loop: consumes consecutive bracket blocks like [a, b] [c]
    while (ctx.is(LBRACKET))
    {
        Range start = ctx.current.range;
        advance(ctx); // consume '['

        // Inner loop: parses comma-separated attributes inside a single [...]
        while (!ctx.eof() && !ctx.is(RBRACKET))
        {
            AttributeDecl* node = ctx.ast.alloc_node(AttributeDecl, start);

            AttributeKind attr_kind;
            switch OUTER: (ctx.current.kind)
            {
            	case IDENT:
		            switch (ctx.current.value)
					{
					    case "private":    attr_kind = PRIVATE; break OUTER;
					    case "nodiscard":  attr_kind = NODISCARD; break OUTER;
					    case "deprecated": attr_kind = DEPRECATED; break OUTER;
					    default:
							attr_kind = CUSTOM;
							break OUTER;
					}
				case IF: attr_kind = IF; break;
				default:
					diagnostics::error(ctx.context, ctx.current.range, "Expected attribute name");
					skip_until(ctx, { COMMA, RBRACKET }, true);
					continue;
            }

            node.attr_kind = attr_kind;

            node.name = ctx.ident(ctx.current);
            advance(ctx);

            if (ctx.is(LPAREN))
            {
                advance(ctx); // consume '('
                if (!ctx.is(RPAREN))
                {
                    node.expr = parse_expr(ctx);
                }
                expect(ctx, node, RPAREN);
            }

            node.range.end = ctx.peek(-1).range.end;
            attrs.push(node);

            // If there's a comma, consume it and parse the next attribute in this block
            if (!consume(ctx, COMMA)) break;
        }

        if (!consume(ctx, RBRACKET))
        {
       		diagnostics::error(ctx.context, ctx.current.range, "Expected ']' to close attributes");
         	break;
        }
    }

    return alloc::clone_slice(ctx.allocator, attrs.array_view());
}

fn Node* parse_global_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_global_decl");
	VarDecl* node = ctx.ast.alloc_node(VarDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;

	node.var_kind = VarDeclKind.VAR_GLOBAL;

	node.flags.is_extern = consume(ctx, EXTERN);
	node.flags.is_const = consume(ctx, CONST);

	if (ctx.is(VAR))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Global variables cant use 'var'");
		node.flags.has_error = true;
		advance(ctx);
	}

	node.type = parse_type(ctx);
	Token ident = expect(ctx, node, IDENT);
	node.name = ctx.ident(ident);

	if (consume(ctx, EQ))
	{
		node.init_expr = parse_expr(ctx);
	}

	expect(ctx, node, EOS);

	return node;
}

fn Node* parse_local_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_global_decl");
	VarDecl* node = ctx.ast.alloc_node(VarDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;

	node.var_kind = VarDeclKind.VAR_LOCAL;

	if (!consume(ctx, VAR))
	{
		node.type = parse_type(ctx);
	}

	node.name = parse_ident(ctx);
	if (!node.name)
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected local variable name");
		skip_until(ctx, { EOS }, true);
		return ctx.ast.error(start);
	}

	if (consume(ctx, TokenKind.EQ))
    {
        advance(ctx);
        node.init_expr = parse_expr(ctx);
    }

	expect(ctx, node, EOS);

	return node;
}

fn Node* parse_fn_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_global_decl");
	FnDecl* node = ctx.ast.alloc_node(FnDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;

	if (consume(ctx, EXTERN))
	{
		node.flags.is_extern = true;
	}

	advance(ctx);

	node.name = parse_ident(ctx);

	if (ctx.is(LESS))
	{
		node.generics = parse_generics_list(ctx);
	}

	expect(ctx, node, LPAREN);

	if (!ctx.is(RPAREN))
	{
		node.params = parse_param_list(ctx);
	}

	expect(ctx, node, RPAREN);

	if (ctx.is(ARROW))
	{
		expect(ctx, node, ARROW);
		node.ret_type = parse_type_expr(ctx);
	}

	if (ctx.is(LBRACE))
	{
		node.body = parse_stmt(ctx);
	}
	else
	{
		expect(ctx, node, EOS);
	}

	return node;
}

<*
 @require ctx.current.kind == STRUCT
*>
fn Node* parse_struct_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_global_decl");
	StructDecl* node = ctx.ast.alloc_node(StructDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;

	advance(ctx);

	if (!ctx.is(IDENT))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected a name for struct");
		node.flags.has_error = true;
	}

	node.name = ctx.ident(ctx.current);
	consume(ctx, IDENT);

	// has generic? <T>
	if (ctx.is(LESS))
	{

	}

	expect(ctx, node, LBRACE);

	List{Node*} fields;
	fields.tinit();

	while (!ctx.is(RBRACE) && !ctx.is(EOF))
	{
		VarDecl* field = ctx.ast.alloc_node(VarDecl, start);
		defer field.range.end = ctx.peek(-1).range.end;

		field.var_kind = VarDeclKind.VAR_FIELD;

		field.type = parse_type(ctx);

		if (!ctx.is(IDENT))
		{
			diagnostics::error(ctx.context, ctx.current.range, "Expected field name");
			field.flags.has_error = true;
		}

		field.name = ctx.ident(ctx.current);
		advance(ctx);

		expect(ctx, field, EOS);

		fields.push(field);
	}

	expect(ctx, node, RBRACE);

	node.fields = alloc::clone_slice(ctx.allocator, fields.array_view());

	return node;
}

<*
 @require ctx.current.kind == ENUM
*>
fn Node* parse_enum_decl(ParseContext* ctx) => @pool()
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_enum_decl");
	EnumDecl* node = ctx.ast.alloc_node(EnumDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;

	advance(ctx);

	if (!ctx.is(IDENT))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected a name for struct");
		node.flags.has_error = true;
	}

	node.name = parse_ident(ctx);

	if (consume(ctx, COLON))
	{
		node.backing_type = parse_type_expr(ctx);
	}

	if (!consume(ctx, LBRACE))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected '{'");
		node.flags.has_error = true;
		return (Node*)node;
	}

	List{Node*} variants;
	variants.init(tmem, 4);
	while ENUM_VARIANT: (!ctx.is(RBRACE) && !ctx.eof())
	{
		if (!ctx.is(IDENT))
		{
			diagnostics::error(ctx.context, ctx.current.range, "Expected enum variant");
			skip_until(ctx, { COMMA, RBRACE });
			consume(ctx, COMMA); // Try to jump to next
			continue;
		}

		VarDecl* variant = ctx.ast.alloc_node(VarDecl, ctx.current.range);
		variant.var_kind = VAR_GLOBAL;
		variant.flags.is_const = true;
		variant.name = ctx.ident(ctx.current);
		advance(ctx);

		// Optional ordinal: "=" expr
		if (consume(ctx, EQ))
		{
			variant.init_expr = parse_expr(ctx);
		}

		variants.push(variant);

		if (!consume(ctx, COMMA)) break;
	}

	if (!consume(ctx, RBRACE))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected '}'");
		node.flags.has_error = true;
	}

	node.variants = alloc::clone_slice(ctx.allocator, variants.array_view());

	return node;
}

fn Node* parse_typedef_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_typedef_decl");
	TypedefDecl* node = ctx.ast.alloc_node(TypedefDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;

	advance(ctx);

	node.name = parse_ident(ctx);

	expect(ctx, node, EQ);

	node.base_type = parse_type_expr(ctx);

	expect(ctx, node, EOS);

	return node;
}

// TODO: Improve
fn Node* parse_param_decl(ParseContext* ctx)
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_param_decl");

	VarDecl* node = ctx.ast.alloc_node(VarDecl, start);
	defer node.range.end = ctx.peek(-1).range.end;

	node.var_kind = VAR_PARAM;

	if (consume(ctx, ELLIPSIS))
	{
		node.var_flags.is_variadic = true;
		return node;
	}

	bool is_ref = consume(ctx, AMP);
	Node* parsed_type = null;
	bool has_ellipsis_after_type = false;

	parsed_type = parse_type_expr(ctx);
	if (parsed_type && parsed_type.kind == ERROR)
	{
		node.flags.has_error = true;
	}

	node.type = parsed_type;

	node.name = parse_ident(ctx);

	return node;
}
