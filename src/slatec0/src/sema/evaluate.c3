module slate::sema::eval;

import slate::core;
import slate::lexer;

<*
 @require node.kind == BUILTIN_EXPR
*>
fn ComptimeValue builtin_ident(CompilerContext* ctx, Node* node)
{
	BuiltinExpr* bi = node.as(BuiltinExpr);
    //if (bi.value.text == "TARGET_OS")   return { .kind = ENUM, .enum_val = ctx.target.os };
    //if (bi.value.text == "TARGET_ARCH") return { .kind = ENUM, .enum_val = ctx.target.arch };

    diagnostics::error(ctx, {}, "Unknown compiler builtin '$$%s'", bi.value.text);
    return { .kind = BOOL, .bool_val = false };
}

/*

fn bool comptime_if(CompilerContext* context, AttributeDecl* attr)
{
	if (attr.attr_kind != IF || attr.expr == null) return true;

	return bool_expr(context, attr.expr);
}

fn bool bool_expr(CompilerContext* ctx, Node* expr)
{
	if (!expr) return false;

	switch (expr.kind)
	{
		case LITERAL_EXPR:
		{
			LiteralExpr* lit = expr.as(LiteralExpr);
			if (lit.lit_kind != BOOL)
			{
				diagnostics::error(ctx, expr.range, "Only a literal of boolean can be evaluated here");
				return false;
			}
			return lit.value == "true";
		}
		case UNARY_EXPR:
		{
			UnaryExpr* unary = expr.as(UnaryExpr);
			if (unary.operator == UNARYOP_NOT)
			{
				return !bool_expr(ctx, unary.expr);
			}
			diagnostics::error(ctx, expr.range, "Unsupported unary operator in attribute condition");
			return false;
		}
		case BINARY_EXPR:
		{
			BinaryExpr* bin = expr.as(BinaryExpr);
			switch (bin.op)
			{
				case OperatorKind.OP_AND:
					return bool_expr(ctx, bin.left) && bool_expr(ctx, bin.right);

				case OperatorKind.OP_OR:
					return bool_expr(ctx, bin.left) || bool_expr(ctx, bin.right);

				case OperatorKind.OP_EQ:
					return string_or_ident(ctx, bin.left) == string_or_ident(ctx, bin.right);

				case OperatorKind.OP_NE:
					return string_or_ident(ctx, bin.left) != string_or_ident(ctx, bin.right);

				default:
					diagnostics::error(ctx, expr.range, "Unsupported binary operator in attribute condition");
					return false;
			}
		}
		case CALL_EXPR:
		{
			CallExpr* call = expr.as(CallExpr);
			PathAtom* callee = call.callee.as(PathAtom);

			if (callee.path.text == "defined")
			{
				if (call.args.len != 1)
				{
					diagnostics::error(ctx, expr.range, "'defined()' expects exactly 1 argument");
					return false;
				}
				String flag = string_or_ident(ctx, call.args[0]);
				return ctx.defines.has_key(flag);
			}

			diagnostics::error(ctx, expr.range, "Unknown function '%s' in condition expression", callee.path.text);
			return false;
		}
		case IDENT_EXPR:
		{
			IdentExpr* id = expr.as(IdentExpr);
			return ctx.defines.has_key(id.text);
		}

		default:
			diagnostics::error(ctx, expr.range, "Invalid expression in [if(...)] attribute");
			return false;
	}
}

fn String string_or_ident(CompilerContext* ctx, Node* node)
{
    if (!node) return "";

    switch (node.kind)
    {
        case LITERAL_EXPR:
            return node.as(LiteralExpr).value;
        case IDENT_EXPR:
        {
            IdentExpr* id = node.as(IdentExpr);
            if (id.ident.text == "target_os")   return ctx.target_info.os_name;
            if (id.ident.text == "target_arch") return ctx.target_info.arch_name;
            return id.ident.text;
        }

        default:
            return "";
    }
}
