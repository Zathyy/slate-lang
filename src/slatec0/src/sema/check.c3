module slate::sema::check;

import slate::sema::lookup;
import slate::sema::scope;
import slate::sema::util;

import slate::core;

/*

fn void typecheck_global_var(SemaContext* ctx, VarDecl* decl)
{
	Type* declared_type = decl.type ? (ctx, decl.type) : null;

	if (decl.init_expr)
	{
		Type* init_type = check::analyze_expr(ctx, decl.init_expr);

		if (declared_type == null)
		{
			sema::set_type(ctx, &decl.node, init_type);
		}
		else if (!check::are_compatible(declared_type, init_type))
		{
			diagnostics::error(ctx.context, decl.init_expr.range,
				"Cannot initialize global variable with mismatched type");
			return;
		}
		else
		{
			sema::set_type(ctx, &decl.node, declared_type);
		}
	}
	else if (declared_type != null)
	{
		sema::set_type(ctx, &decl.node, declared_type);
	}
	else
	{
		diagnostics::error(ctx.context, decl.node.range,
			"Global variable requires a type annotation or initializer");
	}
}

fn Type* analyze_expr(SemaContext* ctx, Node* expr)
{
	if (!expr) return lookup::primitive_type(ctx.context.lookup, TYPE_VOID);

	Type* resolved = null;

	switch (expr.kind)
	{
		case LITERAL_EXPR:
			resolved = lookup::primitive_type(ctx.context.lookup, TYPE_I32);
			break;

		case IDENT_EXPR:
		{
			IdentExpr* ident = expr.as(IdentExpr);
			break;
		}

		case BINARY_EXPR:
		{
			BinaryExpr* bin = expr.as(BinaryExpr);
			Type* lhs_t = analyze_expr(ctx, bin.left);
			Type* rhs_t = analyze_expr(ctx, bin.right);

			if (!are_compatible(lhs_t, rhs_t))
			{
				diagnostics::error(ctx.context, expr.range,
					"Mismatched types in binary expression");
				//resolved = lookup::error_type(ctx.context.lookup);
			}
			else if (util::is_comparison_op(bin.op))
			{
				resolved = lookup::primitive_type(ctx.context.lookup, TYPE_BOOL);
			}
			else
			{
				resolved = lhs_t;
			}
			break;
		}

		case UNARY_EXPR:
		{
			UnaryExpr* un = expr.as(UnaryExpr);
			Type* operand_t = analyze_expr(ctx, un.expr);

			if (un.operator == UNARYOP_NOT && operand_t.kind != TYPE_BOOL)
			{
				diagnostics::error(ctx.context, expr.range,
					"Logical NOT requires a boolean operand");
				//resolved = lookup::error_type(ctx.context.lookup);
			}
			else
			{
				resolved = operand_t;
			}
			break;
		}

		case CALL_EXPR:
		{
			CallExpr* call = expr.as(CallExpr);
			Type* callee_t = analyze_expr(ctx, call.callee);

			if (callee_t.kind != TYPE_FN)
			{
				diagnostics::error(ctx.context, call.callee.range,
					"Expression is not a callable function");
				//resolved = lookup::error_type(ctx.context.lookup);
			}
			else
			{
				//typecheck_call_arguments(ctx, call, callee_t.as_fn);
				//resolved = callee_t.as_fn.return_type;
			}
			break;
		}

		default:
			diagnostics::error(ctx.context, expr.range, "Unsupported expression node");
			//resolved = lookup::error_type(ctx.context.lookup);
			break;
	}

	sema::set_type(ctx, expr, resolved);
	return resolved;
}

fn bool are_compatible(Type* first, Type* second)
{
	return first == second;
}
