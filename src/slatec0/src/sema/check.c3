module slate::sema;

import slate::sema::lookup;
import slate::sema::scope;
import slate::sema::util;

import slate::core;

fn void typecheck_global_var(SemaContext* ctx, VarDecl* decl)
{
	Type* declared_type = decl.resolved_type;

	if (decl.init_expr)
	{
		Type* init_type = check_expr(ctx, decl.init_expr);

		if (declared_type == null)
		{
			sema::set_type(ctx, &decl.node, init_type);
		}
		else if (declared_type != init_type)
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

fn Type* check_expr(SemaContext* ctx, Node* expr)
{
	if (!expr) return lookup::primitive_type(ctx.context.lookup, TYPE_VOID);

	Type* resolved = null;

	switch (expr.kind)
	{
		case LITERAL_EXPR:
			LiteralExpr* lit = expr.as(LiteralExpr);
			switch (lit.lit_kind)
			{
				case INT:
				{
					lit.resolved.integer = lit.value.to_ulong() ?? 0;
					resolved = lookup::primitive_type(ctx.context.lookup, TYPE_I32);
					lit.resolved_type = resolved;
					break;
				}
				case FLOAT:
				{
					lit.resolved._float = lit.value.to_double() ?? 0f;
					resolved = lookup::primitive_type(ctx.context.lookup, TYPE_F32);
					lit.resolved_type = resolved;
					break;
				}
				case BOOL:
				{
					lit.resolved.boolean = lit.value == "true";
					resolved = lookup::primitive_type(ctx.context.lookup, TYPE_BOOL);
					lit.resolved_type = resolved;
					break;
				}
				default:
					// TODO: have a builtin slice type?
					resolved = scope::lookup(ctx, ctx.transient.current_scope, "String").resolved_type;
					lit.resolved_type = resolved;
			}
			break;

		case IDENT_EXPR:
		{
			IdentExpr* ident = expr.as(IdentExpr);
			break;
		}

		case BINARY_EXPR:
		{
			BinaryExpr* bin = expr.as(BinaryExpr);
			Type* lhs_t = check_expr(ctx, bin.left);
			Type* rhs_t = check_expr(ctx, bin.right);

			if (lhs_t != rhs_t)
			{
				diagnostics::error(ctx.context, expr.range,
					"Mismatched types in binary expression");
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
			Type* operand_t = check_expr(ctx, un.expr);

			if (un.operator == UNARYOP_NOT && operand_t.kind != TYPE_BOOL)
			{
				diagnostics::error(ctx.context, expr.range,
					"Logical NOT requires a boolean operand");
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
			Type* callee_t = check_expr(ctx, call.callee);

			if (callee_t.kind != TYPE_FN)
			{
				diagnostics::error(ctx.context, call.callee.range,
					"Expression is not a callable function");
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
			break;
	}

	sema::set_type(ctx, expr, resolved);
	return resolved;
}

fn void check_stmt(SemaContext* ctx, Scope* scope, Stmt* stmt)
{
    if (stmt == null) return;

    switch (stmt.kind)
    {
        case COMPOUND_STMT:
        {
            CompoundStmt* comp = (CompoundStmt*)stmt;
            Scope* block_scope = scope::create(ctx.alloc, stmt.range, scope);

            foreach (Node* node : comp.statements)
            {
                check_stmt(ctx, block_scope, (Stmt*)node);
            }
            break;
        }

        case VAR_DECL:
        {
            VarDecl* decl = (VarDecl*)stmt;
            Type* declared_type = decl.type != null
                ? resolve_type(ctx, scope, decl.type)
                : null;

            if (decl.init_expr != null)
            {
                Type* init_type = check_expr(ctx, decl.init_expr);

                // Type Inference: `var x = 10;`
                if (declared_type == null)
                {
                    declared_type = init_type;
                }
                else if (declared_type != null && init_type != null && (declared_type != init_type))
                {
                    //diagnostics::error(
                    //    ctx.context,
                    //    decl.init_expr.range,
                    //    "Cannot initialize variable of type '%s' with expression of type '%s'",
                    //    type_to_string(declared_type),
                    //    type_to_string(init_type)
                    //);
                }
            }

            if (declared_type == null)
            {
                diagnostics::error(ctx.context, decl.range, "Cannot infer type for variable '%s'", decl.name.text);
                declared_type = lookup::primitive_type(ctx.context.lookup, TYPE_VOID);
            }

            decl.resolved_type = declared_type;
            set_type(ctx, (Node*)decl, declared_type);

            if (!scope::define(scope, decl.name.text, (Decl*)decl))
            {
                diagnostics::error(ctx.context, decl.range, "Redefinition of variable '%s'", decl.name.text);
            }
            break;
        }

        case EXPR_STMT:
        {
            ExprStmt* expr_stmt = (ExprStmt*)stmt;
            check_expr(ctx, expr_stmt.expr_stmt);
            break;
        }

        case RETURN_STMT:
        {
            ReturnStmt* ret = (ReturnStmt*)stmt;
            Type* expected_type = ctx.transient.return_type;
            Type* actual_type = ret.expr != null
                ? check_expr(ctx, ret.expr)
                : lookup::primitive_type(ctx.context.lookup, TYPE_VOID);

            if (expected_type != null && actual_type != null && expected_type != actual_type)
            {
                //diagnostics::error(
                //    ctx.context,
                //    stmt.range,
                //    "Mismatched return type. Expected '%s', got '%s'",
                //    type_to_string(expected_type),
                //    type_to_string(actual_type)
                //);
            }
            break;
        }

        case IF_STMT:
        {
            IfStmt* if_stmt = (IfStmt*)stmt;
            Type* cond_type = check_expr(ctx, if_stmt.condition);

            if (cond_type != null && cond_type.canonical.kind != TYPE_BOOL)
            {
                diagnostics::error(ctx.context, if_stmt.condition.range, "If condition must be a boolean expression");
            }

            check_stmt(ctx, scope, (Stmt*)if_stmt.then_body);
            if (if_stmt.else_body != null)
            {
                check_stmt(ctx, scope, (Stmt*)if_stmt.else_body);
            }
            break;
        }

        default:
            break;
    }
}
