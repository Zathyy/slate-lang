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
		case LBRACE:
			return parse_compound_stmt(ctx);
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

    if (expr.kind == NodeKind.CALL_EXPR)
    {
        return expr;
    }

    if (expr.kind == NodeKind.BINARY_EXPR)
    {
        BinaryExpr* bin = (BinaryExpr*)expr;
        if (is_assignment_op(bin.op))
        {
            return expr;
        }
    }

    diagnostics::error(ctx.context, expr.range, "Expression statement has no side effect (Rule A violation)");
    expr.flags.has_error = true;
    return expr;
}
