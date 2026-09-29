module slate::parser;

import slate::core;
import slate::lexer;

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
