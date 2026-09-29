module slate::parser;

import slate::core;
import slate::lexer;

import std::collections;

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
   		case STRING_LITERAL: kind = STRING;
     	case CHAR_LITERAL:   kind = CHAR;
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
	Node* right = parse_expr(ctx, prec);

	BinaryExpr* node = ctx.ast.alloc_node(BinaryExpr, { start.start, right.range.end, ctx.context.current_source_file });
	node.left = left;
	node.right = right;
	node.op = core::binaryop_from_token(kind);
	return (Node*)node;
}

fn Node* parse_cast_expr(ParseContext* ctx)
{
	Range start  = ctx.current.range;
	advance(ctx);

	CastExpr* node = ctx.ast.alloc_node(CastExpr, start);
	defer node.range.end = ctx.peek(-1).range.end;

	expect(ctx, node, LESS);
	node.inner = parse_type(ctx);
	expect(ctx, node, GREATER);

	expect(ctx, node, LPAREN);
	node.operand = parse_expr(ctx, UNARY);
	expect(ctx, node, RPAREN);

	return (Node*)node;
}

fn Node* parse_unary_expr(ParseContext* ctx)
{
	diagnostics::log_debug("parse_unary_expr");
	Range start = ctx.current.range;
	if (ctx.is(MINUS))
	{
		if (ctx.peek(1).kind == INT_LITERAL)
		{
			advance(ctx);
			Node* lit = parse_expr(ctx);
			lit.as(LiteralExpr).is_negative = true;
			return lit;
		}
	}
	UnaryExpr* node = ctx.ast.alloc_node(UnaryExpr, start);
	defer node.range.end = ctx.peek(-1).range.end;
	UnaryOpKind? op  = core::unaryop_from_token(ctx.current.kind);
	if (catch op)
	{
		diagnostics::error(ctx.context, ctx.current.range,"Not a unary operator (%s)", ctx.current.kind);
	}
	else
	{
		node.operator = op;
	}
	advance(ctx);
	node.expr = parse_expr(ctx, UNARY);
	return (Node*)node;
}

fn Node* parse_post_unary_expr(ParseContext* ctx, Node* left, Precedence bp)
{
	Range start = ctx.current.range;
	PostUnaryExpr* node = ctx.ast.alloc_node(PostUnaryExpr, start);
	defer node.range.end = ctx.peek(-1).range.end;
	UnaryOpKind? op = core::unaryop_from_token(ctx.current.kind);
	if (catch op)
	{
		diagnostics::error(ctx.context, ctx.current.range,"Not a unary operator (%s)", ctx.current.kind);
	}
	else
	{
		node.operator = op;
	}
	node.expr = left;
	advance(ctx);
	return (Node*)node;
}

fn Node* parse_call_expr(ParseContext* ctx, Node* callee)
{
	Range start = ctx.current.range;
	CallExpr* node = ctx.ast.alloc_node(CallExpr, callee.range);
	defer node.range.end = ctx.peek(-1).range.end;
	expect(ctx, node, LPAREN);
	node.callee = callee;

	diagnostics::log_debug("call_expr: %s", ctx.current.value);

	if (!ctx.is(RPAREN) && !ctx.is(EOS) && !ctx.eof())
	{
		diagnostics::log_debug("call_expr - args");
		node.args = parse_arg_list(ctx);
	}

	expect(ctx, node, RPAREN);

	Node* body;
	if (ctx.is(LBRACE))
	{
		body = parse_compound_stmt(ctx);
	}

	return (Node*)node;
}

<*
 param_list ::= ('...' arg | arg (',' arg)*)?
 parameter ::= ((param_path '=')? expr) | param_path
*>
fn NodeArray parse_arg_list(ParseContext* ctx) => @pool()
{
	List{Node*} args;
	args.tinit();

	while (!ctx.eof() && !ctx.is(RPAREN))
	{
		int pos_before  = ctx.pos;
		Node* expr = null;
		Range start_pos = ctx.current.range;
		if (ctx.is(RPAREN)) break;

		diagnostics::log_debug("parse arg - %s", ctx.current.value);

		expr = parse_expr(ctx);

		if (expr.kind == IDENT_EXPR && consume(ctx, COLON))
		{
			IdentExpr* ident = expr.as(IdentExpr);
			expr = (Node*)ctx.ast.alloc_node(NamedArgExpr, start_pos);
			NamedArgExpr* named = expr.as(NamedArgExpr);
			named.name = ident.ident;

			named.value = parse_expr(ctx);
			named.range.end = ctx.peek(-1).range.end;
		}

		diagnostics::log_debug("parse arg AFTER - %s", ctx.current.value);

		args.push(expr);

		if (ctx.pos == pos_before)
		{
			diagnostics::error(
				ctx.context,
				ctx.current.range,
				"Parser loop stalled in argument list at token: %s",
				ctx.current.kind
			);
			advance(ctx);
		}

		if (!consume(ctx, COMMA)) break;
		if (ctx.is(RPAREN)) break;
	}

	return alloc::clone_slice(ctx.allocator, args.array_view());
}

fn Node* parse_group_expr(ParseContext* ctx)
{
	diagnostics::log_debug("parse_group_expr");
	Range start = ctx.current.range;

	GroupExpr* group = ctx.ast.alloc_node(GroupExpr, ctx.current.range);
	defer group.range.end = ctx.peek(-1).range.end;

	if (!consume(ctx, LPAREN))
	{
		diagnostics::error(
			ctx.context,
			ctx.current.range,
			"Expected '(' got '%s'",
			ctx.current.kind.description
		);
	}
	Node* inner = parse_expr(ctx);
	if (!consume(ctx, RPAREN))
	{
		diagnostics::error(
			ctx.context,
			ctx.current.range,
			"Expected ')' got '%s'",
			ctx.current.kind.description
		);
	}

	group.inner = inner;
	return (Node*)group;
}
