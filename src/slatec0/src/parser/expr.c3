module slate::parser;

import slate::core;
import slate::lexer;

<*
 Handles primitive and named type identifiers plus postfix pointer, array,
 slice, vector, and generic type forms.
*>
fn Node* parse_type_expr(ParseContext* ctx, Node* path_expr = null)
{
	Range start = ctx.current.range;

	diagnostics::log_debug("parse_type_expr");

	TypeExpr* current_type = ctx.ast.alloc_node(TypeExpr, start);
	defer current_type.range.end = ctx.peek(-1).range.end;
	current_type.is_const = consume(ctx, CONST);

	// Check for built-in primitive keywords
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
			current_type.flags.has_error = true;
		}
	}

	while (true)
	{
		Token t = ctx.current;

		if (t.kind == ASTERISK)
		{
			advance(ctx);

			TypeExpr* ptr_node = ctx.ast.alloc_node(TypeExpr, { start.start, ctx.current.range.end });

			ptr_node.type_kind = TYPE_POINTER;
			ptr_node.modify.base = current_type; // The previous node becomes the base

			current_type = ptr_node;
			continue;
		}

		if (t.kind == LBRACKET)
		{
			advance(ctx);

			TypeExpr* arr_node = ctx.ast.alloc_node(TypeExpr, { start.start, ctx.current.range.end });

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
				expect(ctx, arr_node, RBRACKET);
			}

			arr_node.range.end = ctx.peek(-1).range.end;
			current_type = arr_node;
			continue;
		}

		// Handle Generics: '{' ... '}'
		if (t.kind == LESS)
		{
			TypeExpr* gen_node = ctx.ast.alloc_node(TypeExpr, { start.start, ctx.current.range.end });

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

fn Node* parse_literal_expr(ParseContext* ctx)
{
	Range start = ctx.current.range;

	diagnostics::log_debug("parse_literal_expr");

	LiteralExpr* node = ctx.ast.alloc_node(LiteralExpr, start);
	defer node.range.end = ctx.peek(-1).range.end;

	LiteralKind kind;
	switch (ctx.current.kind)
	{
		case NULL: kind = NULL;
		case TRUE: kind = BOOL;
		case FALSE: kind = BOOL;
		case INT_LITERAL: kind = INT;
		case FLOAT_LITERAL: kind = FLOAT;
 		case BYTES_LITERAL: kind = CHAR;
 		default: unreachable("Unknown literal kind");
	}

	node.lit_kind = kind;
	node.value = ctx.current.value.copy(ctx.allocator);
	advance(ctx);

	return node;
}

fn Node* parse_binary_expr(ParseContext* ctx, Node* left, Precedence prec)
{
	Range start  = ctx.current.range;
	TokenKind kind = ctx.current.kind;
	advance(ctx);
	Node* right = parse_expr(ctx);

	BinaryExpr* node = ctx.ast.alloc_node(BinaryExpr, { start.start, right.range.end });
	node.left = left;
	node.right = right;
	node.op = core::binaryop_from_token(kind);
	return (Node*)node;
}
