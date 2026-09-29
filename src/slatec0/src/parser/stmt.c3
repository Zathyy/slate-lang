module slate::parser;

import slate::lexer;
import slate::core;

import std::collections;

fn Node* parse_stmt(ParseContext* ctx)
{
	Token t = ctx.current;

	diagnostics::log_debug("parse_stmt: current = %s (%s)", t.value, t.kind.description);

	if (t.kind.is_primitive())
    {
        return parse_local_decl(ctx);
    }

	switch (t.kind)
	{
		case IF:
			return parse_if_stmt(ctx);
		case WHILE:
			return parse_while_stmt(ctx);
		case LBRACE:
			return parse_compound_stmt(ctx);
		case RETURN:
			return parse_return_stmt(ctx);
		case IDENT:
			return parse_ident_stmt(ctx);
		case VAR:
		case CONST:
			return parse_local_decl(ctx);
		case EOS:
			advance(ctx);
			return (Node*)ctx.ast.alloc_node(NopStmt, t.range);
		default:
			break;
	}


	diagnostics::error(ctx.context, t.range, "Unexpected '%s' found when expecting a statement, synchronizing!", t.kind.description);
	Node* error = ctx.ast.error(t.range);
	advance(ctx);
	return error;
}


<*
 compound_stmt ::= ('{' stmt* '}')
 @require ctx.current.kind == LBRACE
*>
fn Node* parse_compound_stmt(ParseContext* ctx) => @pool()
{
	CompoundStmt* node = ctx.ast.alloc_node(CompoundStmt, ctx.current.range);
	defer node.range.end = ctx.current.range.end;
	advance(ctx);

	List{Node*} temp_stmts;
	temp_stmts.init(tmem, 8);

	while (!ctx.is(RBRACE) && !ctx.eof())
	{
		Range start_range = ctx.current.range;
		Node* stmt = parse_stmt(ctx);
		if (ctx.current.range == start_range)
		{
			diagnostics::error(ctx.context, ctx.current.range, "Unexpected token in block");
			node.flags.has_error = true;
		}
		else
		{
			if (stmt.flags.has_error) node.flags.has_error = true;
			temp_stmts.push(stmt);
		}
	}

	if (!consume(ctx, RBRACE))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected '}' to terminate compound");
		node.flags.has_error = true;
	}

	node.statements = alloc::clone_slice(ctx.allocator, temp_stmts.array_view());

	return (Node*)node;
}

fn Node* parse_ident_stmt(ParseContext* ctx)
{
	Range start = ctx.current.range;
    if (is_type_decl_lookahead(ctx))
    {
        return parse_local_decl(ctx);
    }

    Node* expr = parse_expr(ctx);

    if (!consume(ctx, EOS))
    {
        diagnostics::error(ctx.context, ctx.current.range, "Expected ';' after expression statement");
        return (Node*)ctx.ast.error(ctx.current.range);
    }

    ExprStmt* stmt = ctx.ast.alloc_node(ExprStmt, start);
    stmt.range.end = ctx.peek(-1).range.end;
    stmt.expr_stmt = expr;

    if (expr.kind == NodeKind.CALL_EXPR)
    {
        return stmt;
    }

    if (expr.kind == NodeKind.BINARY_EXPR)
    {
        BinaryExpr* bin = (BinaryExpr*)expr;
        if (is_assignment_op(bin.op))
        {
            return stmt;
        }
    }

    if (expr.kind == NodeKind.POST_UNARY_EXPR || expr.kind == NodeKind.UNARY_EXPR)
    {
        UnaryExpr* un = (UnaryExpr*)expr;
        if (un.operator == UnaryOpKind.UNARYOP_INC || un.operator == UNARYOP_DEC)
        {
            return stmt;
        }
    }

    diagnostics::error(ctx.context, expr.range, "Expression statement has no side effect (Rule A violation)");
    stmt.flags.has_error = true;
    return stmt;
}

fn Node* parse_return_stmt(ParseContext* ctx)
{
	Range start = ctx.current.range;
	advance(ctx);

	ReturnStmt* node = ctx.ast.alloc_node(ReturnStmt, start);
	defer node.range.end = ctx.peek(-1).range.end;

	if (!ctx.is(EOS))
	{
		node.expr = parse_expr(ctx);
	}

	if (!consume(ctx, EOS))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected ';'");
		node.flags.has_error = true;
	}

	return (Node*)node;
}

fn Node* parse_if_stmt(ParseContext* ctx)
{
	Range start = ctx.current.range;
	advance(ctx);
	IfStmt* node = ctx.ast.alloc_node(IfStmt, start);
	defer node.range.end = ctx.current.range.end;

	if (!consume(ctx, LPAREN))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected '(' after 'if'");
		node.flags.has_error = true;
	}

	node.condition = parse_decl_or_expr(ctx);

	if (!node.condition || node.condition.flags.has_error)
	{
		node.flags.has_error = true;
	}

	if (!consume(ctx, RPAREN))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected ')' to close if-condition");
		node.flags.has_error = true;
	}

	node.then_body = parse_stmt(ctx);
	if (!node.then_body || node.then_body.flags.has_error)
	{
		node.flags.has_error = true;
	}

	if (consume(ctx, ELSE))
	{
		node.else_body = parse_stmt(ctx);
		if (!node.else_body || node.else_body.flags.has_error)
		{
			node.flags.has_error = true;
		}
	}

	return (Node*)node;
}

fn Node* parse_while_stmt(ParseContext* ctx)
{
	Range start = ctx.current.range;
	advance(ctx);

	WhileStmt* node = ctx.ast.alloc_node(WhileStmt, start);
	defer node.range.end = ctx.peek(-1).range.end;

	if (!consume(ctx, LPAREN))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected '(' to open while header");
		node.flags.has_error = true;
	}

	node.cond = parse_decl_or_expr(ctx);

	if (!consume(ctx, RPAREN))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected ')' to close while header");
		node.flags.has_error = true;
	}

	Location prev_loc = ctx.current.range.start;

	node.body = parse_stmt(ctx);

	Location body_loc = node.body.range.start;
	if (node.body.kind != COMPOUND_STMT && prev_loc.line != body_loc.line)
	{
		diagnostics::error(ctx.context, node.body.range,
				"Single statement after 'while' must be on the same line or in {}");
		node.flags.has_error = true;
	}

	return (Node*)node;
}
