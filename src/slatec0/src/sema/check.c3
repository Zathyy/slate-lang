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

					if (lit.resolved.integer <= int::max)
                    {
                        resolved = lookup::primitive_type(ctx.context.lookup, TYPE_I32);
                    }
                    else
                    {
                        resolved = lookup::primitive_type(ctx.context.lookup, TYPE_I64);
                    }

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
			String name = ident.ident.text;
		    // Look up symbol in the active scope
		    Decl* decl = scope::lookup(ctx, ctx.transient.current_scope, ident.ident.text);

		    if (decl == null)
		    {
		        diagnostics::error(ctx.context, expr.range,
		            "Undeclared identifier '%s'", ident.ident.text);
		        resolved = lookup::primitive_type(ctx.context.lookup, TYPE_VOID);
		    }
		    else
		    {
		        ident.decl = decl;
		        resolved = decl.resolved_type;
		    }

			ident.resolved_type = resolved;
			break;
		}

		case BINARY_EXPR:
		{
			BinaryExpr* bin = expr.as(BinaryExpr);
			Type* lhs_t = check_expr(ctx, bin.left);
			Type* rhs_t = check_expr(ctx, bin.right);

			if (lhs_t != rhs_t)
		    {
		        if (bin.right.kind == LITERAL_EXPR && lhs_t.is_integer())
		        {
		            LiteralExpr* lit = bin.right.as(LiteralExpr);
		            if (lit.lit_kind == INT)
		            {
						if (!lookup::fits_in_integer(lit.resolved.integer, lit.is_negative, lhs_t))
						{
							diagnostics::error(ctx.context, lit.range, "int literal does not fit in: %s", lhs_t.name);
						}

		                lit.resolved_type = lhs_t;
		                rhs_t = lhs_t;
		            }
		        }
		        else if (bin.left.kind == LITERAL_EXPR && rhs_t.is_integer())
		        {
		            LiteralExpr* lit = bin.left.as(LiteralExpr);
		            if (lit.lit_kind == INT)
		            {
						if (!lookup::fits_in_integer(lit.resolved.integer, lit.is_negative, rhs_t))
						{
							diagnostics::error(ctx.context, lit.range, "int literal does not fit in: %s", rhs_t.name);
						}
		                lit.resolved_type = rhs_t;
		                lhs_t = rhs_t;
		            }
		        }
		    }

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
		case CAST_EXPR:
        {
            CastExpr* cast = expr.as(CastExpr);

            Type* operand_t = check_expr(ctx, cast.operand);
            Type* target_t = resolve_type(ctx, ctx.transient.current_scope, cast.inner);

            if (cast.operand != null)
            {
                ((Expr*)cast.operand).resolved_type = operand_t;
            }

            if (cast.inner != null)
            {
                cast.inner.resolved_type = target_t;
            }

            if (target_t == null)
            {
                diagnostics::error(ctx.context, cast.inner != null ? cast.inner.range : expr.range,
                    "Unknown target type in cast expression");
            }
            else if (operand_t != null)
            {
                if (!is_valid_cast(operand_t, target_t))
                {
                    diagnostics::error(ctx.context, expr.range,
                        "Cannot cast expression of type '%s' to '%s'",
                        operand_t.name,
                        target_t.name);
                }
            }

            resolved = target_t;
            cast.resolved_type = resolved;
            break;
        }
        case POST_UNARY_EXPR:
        {
            PostUnaryExpr* post = expr.as(PostUnaryExpr);
            Type* operand_t = check_expr(ctx, post.expr);
            post.decl = operand_t.data.decl;

            // Ensure operand is a valid numeric or pointer type
            if (operand_t != null && !operand_t.is_numeric() && operand_t.kind != TYPE_POINTER)
            {
                diagnostics::error(ctx.context, expr.range,
                    "Cannot increment or decrement non-numeric type '%s'", operand_t.name);
            }

            // Ensure operand is an L-value (e.g., variable, field access, index expression)
            if (!util::is_lvalue(post.expr))
            {
                diagnostics::error(ctx.context, post.expr.range,
                    "Cannot apply increment/decrement to an rvalue expression");
            }

            // Ensure the underlying variable is not const
            if (post.expr.kind == IDENT_EXPR)
            {
                IdentExpr* ident = post.expr.as(IdentExpr);
                if (ident.decl != null && ident.decl.kind == VAR_DECL)
                {
                    VarDecl* var_decl = (VarDecl*)ident.decl;
                    if (var_decl.type.is_const) // or check if decl.kind == CONST_DECL
                    {
                        diagnostics::error(ctx.context, post.expr.range,
                            "Cannot mutate constant variable '%s'", ident.ident.text);
                    }
                }
            }

            // Postfix expressions return the original type of the operand
            resolved = operand_t;
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

    // Synchronize current_scope for any sub-expression checks
    Scope* prev_scope = ctx.transient.current_scope;
    ctx.transient.current_scope = scope;
    defer ctx.transient.current_scope = prev_scope;

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

            if (Decl* existing = scope::define(scope, decl.name.text, (Decl*)decl))
            {
            	diagnostics::note(ctx.context, existing.range, "Previous use of '%s' was here", decl.name.text);
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
