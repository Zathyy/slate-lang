module slate::sema::eval;

import slate::core;
import slate::lexer;
import slate::sema::util;

/*

<*
 @require node.kind == BUILTIN_EXPR
*>
fn ComptimeValue builtin(CompilerContext* ctx, Node* node)
{
	BuiltinExpr* bi = node.as(BuiltinExpr);
    if (bi.value.text == "TARGET_OS")   return { .kind = ENUM, .enum_val.variant_id = (uint)ctx.target.os };
    if (bi.value.text == "TARGET_ARCH") return { .kind = ENUM, .enum_val.variant_id = (uint)ctx.target.arch };

    diagnostics::error(ctx, {}, "Unknown compiler builtin '$$%s'", bi.value.text);
    return { .kind = BOOL, .bool_val = false };
}

/*

fn bool comptime_if(CompilerContext* context, AttributeDecl* attr)
{
	if (attr.attr_kind != IF || attr.expr == null) return true;

	return bool_expr(context, attr.expr);
}

*/

/*
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

*/

fn bool is_node_enabled(CompilerContext* ctx, Node* node)
{
    if (!node) return false;

    Node* found_attr = null;
    if (!util::has_attribute(node, AttributeKind.IF, &found_attr)) return true;
    AttributeDecl* attr = found_attr.as(AttributeDecl);
    if (!attr || !attr.expr)
    {
        diagnostics::error(ctx, node.range, "[if(...)] attribute requires a condition expression");
        return false;
    }

    ComptimeValue res = comptime_expr(ctx, attr.expr);

    if (res.kind != BOOL)
    {
        diagnostics::error(ctx, attr.expr.range,
            "Condition in [if(...)] must evaluate to a boolean constant");
        return false;
    }

    return res.bool_val;
}

fn ComptimeValue comptime_expr(CompilerContext* ctx, Node* expr)
{
    if (!expr) return { .kind = BOOL, .bool_val = false };

    switch (expr.kind)
    {
        case BUILTIN_EXPR:
        {
            BuiltinExpr* builtin = expr.as(BuiltinExpr);
            return eval::builtin(ctx, builtin);
        }

        case BINARY_EXPR:
        {
            BinaryExpr* bin = expr.as(BinaryExpr);
            ComptimeValue lhs = comptime_expr(ctx, bin.left);
            ComptimeValue rhs = comptime_expr(ctx, bin.right);

            if (bin.op == OP_EQ)
            {
                return { .kind = BOOL, .bool_val = lhs == rhs };
            }
            if (bin.op == OP_NE)
            {
                return { .kind = BOOL, .bool_val = !(lhs == rhs) };
            }
            break;
        }

        case IDENT_EXPR:
        case ACCESS_EXPR:
        {
      		String qname = get_qualified_name(ctx, expr);

            VarInfo* var_info = ctx.registry.globals.get(qname) ?? null;
            if (!var_info && !qname.contains("::"))
            {
                String env_qname = string::format(ctx.alloc, "std::core::env::%s", qname);
                var_info = ctx.registry.globals.get(qname) ?? null;
            }

            if (var_info)
            {
                if (var_info.const_value.kind != UNKNOWN)
                {
                    return var_info.const_value;
                }

                VarDecl* decl = var_info.node.as(VarDecl);
                if (decl && decl.init_expr)
                {
                    var_info.const_value = comptime_expr(ctx, decl.init_expr);
                    return var_info.const_value;
                }
            }

            diagnostics::error(ctx, expr.range, "Unknown global or define symbol '%s'", qname);
            return { .kind = BOOL, .bool_val = false };
        }

        case LITERAL_EXPR:
        {
            LiteralExpr* lit = expr.as(LiteralExpr);
            return { .kind = BOOL, .bool_val = lit.value == "true" };
        }

        default:
            break;
    }

    diagnostics::error(ctx, expr.range, "Expression is not a valid compile-time condition");
    return { .kind = BOOL, .bool_val = false };
}

fn String get_qualified_name(CompilerContext* ctx, Node* node)
{
    if (!node) return "";
    switch (node.kind)
    {
        case IDENT_EXPR:
            return node.as(IdentExpr).ident.text;
        case ACCESS_EXPR:
        {
            AccessExpr* acc = node.as(AccessExpr);
            String left = get_qualified_name(ctx, acc.left);
            String right = get_qualified_name(ctx, acc.right);
            if (left.len == 0) return right;
            if (right.len == 0) return left;
            return string::format(ctx.alloc, "%s::%s", left, right);
        }
        case PATH_ATOM:
            return node.as(PathAtom).path.text;
        default:
            return "";
    }
}
