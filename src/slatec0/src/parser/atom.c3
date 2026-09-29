module slate::parser;

import slate::core;
import slate::lexer;

import std::collections;

fn Node* parse_path(ParseContext* ctx, bool prefix = false) => @pool()
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_path");

	if (!ctx.is(IDENT))
	{
		if (prefix) return null;
		diagnostics::error(ctx.context, ctx.current.range, "Expected a path identifier");
		return ctx.ast.error(start);
	}

	PathAtom* node = ctx.ast.alloc_node(PathAtom, start);
	defer node.range.end = ctx.peek(-1).range.end;
	DString sb; sb.tinit();

	while (ctx.is(IDENT))
	{
		if (prefix)
		{
			if (ctx.peek(1).kind == SCOPE)
			{
				sb.append(ctx.current.value);
				sb.append("::");
				advance(ctx, 2);
			}
			else
			{
				break;
			}
		}
		else
		{
			sb.append(ctx.current.value);
			advance(ctx);

			if (consume(ctx, SCOPE))
			{
				sb.append("::");
				if (ctx.current.kind == IDENT)
				{
					continue;
				}
				else
				{
					diagnostics::error(ctx.context, ctx.current.range, "Expected an identifier after '::'");
					node.flags.has_error = true;
					break;
				}
			}
			break;
		}
	}

	node.path = ctx.ident_string(sb.str_view());
	return (Node*)node;
}

<*
 generic_param_list ::= '<' expr ( ',' expr )* '>'
*>
fn NodeArray parse_generics_list(ParseContext* ctx) => @pool()
{
	if (!consume(ctx, LESS)) return {};
	List{Node*} params;
	params.init(tmem, 4);

	while (!ctx.eof())
	{
		if (ctx.is(GREATER)) break;
		// This parses 'foo::Bar' via SCOPE precedence, but STOPS before treating '>' as a greater-than comparison!
		Node* param = parse_expr(ctx, Precedence.RELATIONAL + 1);
		params.push(param);
		if (!consume(ctx, COMMA)) break;
	}

	if (!consume(ctx, GREATER))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected closing '>' after generic parameter list");
	}

	return alloc::clone_slice(ctx.allocator, params.array_view());
}

fn Ident* parse_ident(ParseContext* ctx)
{
	if (!ctx.is(IDENT))
	{
		return null;
	}

	Ident* ident = ctx.ident(ctx.current);
	advance(ctx);

	return ident;
}

fn NodeArray parse_param_list(ParseContext* ctx) => @pool()
{
	List{Node*} params; params.init(tmem);

	while (!ctx.eof() && !ctx.is(RPAREN))
	{
		Range param_start = ctx.current.range;

		Node* param = parse_param_decl(ctx);
		params.push(param);

		if (ctx.current.range == param_start)
		{
			diagnostics::error(ctx.context, ctx.current.range, "Invalid parameter declaration");
			skip_until(ctx, { COMMA, RPAREN, EOS });
			break;
		}

		if (consume(ctx, COMMA))
		{
			if (ctx.is(RPAREN))
			{
				diagnostics::error(ctx.context, ctx.current.range, "Trailing comma in parameter list");
				break;
			}
		}
		else if (!ctx.is(RPAREN))
		{
			diagnostics::error(ctx.context, ctx.current.range, "Expected ',' or ')' in parameter list");
			skip_until(ctx, { RPAREN, EOS });
			break;
		}
	}

	return alloc::clone_slice(ctx.allocator, params.array_view());
}

fn TypeDescriptor* make_type_descriptor(ParseContext* ctx)
{
	return alloc::new(ctx.allocator, TypeDescriptor);
}

<*
 Handles primitive and named type identifiers plus postfix pointer, array,
 slice, vector, and generic type forms.
*>
fn TypeDescriptor* parse_type(ParseContext* ctx, Node* path_expr = null)
{
	Range start = ctx.current.range;

	diagnostics::log_debug("parse_type_expr");

	TypeDescriptor* current_type = make_type_descriptor(ctx);
	current_type.range = { start.start, start.end, start.file_id };
	defer current_type.range.end = ctx.peek(-1).range.end;
	current_type.is_const = consume(ctx, CONST);

	if (ctx.current.kind.is_primitive())
	{
		Token t = ctx.current;
		advance(ctx);

		current_type.type_kind = TYPE_IDENTIFIER;
		current_type.unresolved.name = ctx.ident(t);
		current_type.unresolved.path = null;
	}
	else
	{
		Node* path = path_expr ? path_expr : parse_path(ctx, true);

		if (ctx.is(IDENT))
		{
			current_type.type_kind = TYPE_IDENTIFIER;
			current_type.unresolved.name = ctx.ident(ctx.current);
			current_type.unresolved.path = path;
			advance(ctx);
		}
		else
		{
			diagnostics::error(ctx.context, ctx.current.range, "Expected type identifier");
		}
	}

	bool has_optional = false;

	while (true)
	{
		Token t = ctx.current;

		if (t.kind == ASTERISK)
		{
			advance(ctx);

			TypeDescriptor* ptr_node = make_type_descriptor(ctx);
			ptr_node.range = { start.start, ctx.current.range.end, start.file_id };

			ptr_node.type_kind = TYPE_POINTER;
			ptr_node.modify.base = current_type; // The previous node becomes the base

			current_type = ptr_node;
			continue;
		}

		if (t.kind == AMP)
		{
			advance(ctx);

			TypeDescriptor* ref_node = make_type_descriptor(ctx);
			ref_node.range = { start.start, ctx.current.range.end, start.file_id };

			ref_node.type_kind = TYPE_REF;
			ref_node.modify.base = current_type;

			current_type = ref_node;

			continue;
		}

		if (t.kind == LBRACKET)
		{
			advance(ctx);

			has_optional = false;

			TypeDescriptor* arr_node = make_type_descriptor(ctx);
			arr_node.range = { start.start, ctx.current.range.end, start.file_id };

			if (ctx.is(RBRACKET))
			{
				advance(ctx);
				arr_node.type_kind = TYPE_SLICE;
				arr_node.modify.base = current_type;
			}
			else if (ctx.is(ASTERISK) && ctx.peek(1).kind == RBRACKET)
			{
				advance(ctx); // Consume '*'
				advance(ctx); // Consume ']'

				arr_node.type_kind = TYPE_ARRAY;
				arr_node.array.base = current_type;
				arr_node.array.len_expr = null; // null represents inferred array size [*]
			}
			else
			{
				arr_node.type_kind = TYPE_ARRAY;
				arr_node.array.base = current_type;
				arr_node.array.len_expr = parse_expr(ctx);
				if (!consume(ctx, RBRACKET))
				{
					diagnostics::error(ctx.context, ctx.current.range, "Expected ']' to close array");
				}
			}

			arr_node.range.end = ctx.peek(-1).range.end;
			current_type = arr_node;
			continue;
		}

		if (t.kind == LESS)
		{
			TypeDescriptor* gen_node = make_type_descriptor(ctx);
			gen_node.range = { start.start, ctx.current.range.end, start.file_id };

			gen_node.type_kind = TYPE_GENERIC;
			gen_node.generic.base = current_type;
			gen_node.generic.params = parse_generics_list(ctx);

			gen_node.range.end = ctx.current.range.end;

			current_type = gen_node;
			continue;
		}

		break;
	}

	return current_type;
}
