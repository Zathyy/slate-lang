module slate::sema;

import slate::core;
import slate::lexer;
import slate::sema::util;

/*

<*
 @require node.kind == BUILTIN_EXPR
*>
fn ComptimeValue builtin(SemaContext* ctx, Node* node)
{
	BuiltinExpr* bi = node.as(BuiltinExpr);
    if (bi.value.text == "TARGET_OS")   return { .kind = ENUM, .enum_val.variant_id = (uint)ctx.target.os };
    if (bi.value.text == "TARGET_ARCH") return { .kind = ENUM, .enum_val.variant_id = (uint)ctx.target.arch };

    diagnostics::error(ctx, {}, "Unknown compiler builtin '$$%s'", bi.value.text);
    return { .kind = BOOL, .bool_val = false };
}

fn bool comptime_if(SemaContext* context, AttributeDecl* attr)
{
	if (attr.attr_kind != IF || attr.expr == null) return true;

	return bool_expr(context, attr.expr);
}

*/

fn bool evaluate_feature(SemaContext* ctx, String feat)
{
    return ctx.context.features.contains(feat);
}

fn bool eval_feature_expr(SemaContext* ctx, Node* expr)
{
    if (!expr) return false;

    switch (expr.kind)
    {
        case IDENT_EXPR:
        {
            IdentExpr* ident = expr.as(IdentExpr);
            return evaluate_feature(ctx, ident.ident.text);
        }

        case LITERAL_EXPR:
        {
            return expr.as(LiteralExpr).value == "true";
        }

        case UNARY_EXPR:
        {
            UnaryExpr* un = expr.as(UnaryExpr);
            if (un.operator == UnaryOpKind.UNARYOP_NOT) // !feature
            {
                return !eval_feature_expr(ctx, un.expr);
            }
            break;
        }

        case BINARY_EXPR:
        {
            BinaryExpr* bin = expr.as(BinaryExpr);

            if (bin.op == OP_AND)
            {
                // Short-circuit AND
                return eval_feature_expr(ctx, bin.left) && eval_feature_expr(ctx, bin.left);
            }
            if (bin.op == OP_OR)
            {
                // Short-circuit OR
                return eval_feature_expr(ctx, bin.right) || eval_feature_expr(ctx, bin.right);
            }
            break;
        }
        case GROUP_EXPR:
        {
            return eval_feature_expr(ctx, expr.as(GroupExpr).inner);
        }

        default: break;
    }

    diagnostics::error(
        ctx.context,
        expr.range,
        "[feature(...)] attributes only accept feature identifiers, '!', '&&', '||', and parentheses"
    );
    return false;
}

fn bool is_node_enabled(SemaContext* ctx, Decl* decl)
{
    if (!decl) return false;

    Node* attribute;
    if (!util::has_attribute(decl, AttributeKind.FEATURE, &attribute))
    {
        return true;
    }

    AttributeDecl* attr = attribute.as(AttributeDecl);
    return eval_feature_expr(ctx, attr.expr);
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


fn ulong eval_const_int(SemaContext* ctx, Node* expr)
{
    if (expr == null) return 0;

    switch (expr.kind)
    {
        case LITERAL_EXPR:
        {
            LiteralExpr* lit = expr.as(LiteralExpr);

            if (lit.lit_kind == INT)
            {
                return lit.value.to_ulong() ?? 0;
            }

            diagnostics::log_error("[Sema]: Expected integer literal for array length");
            return 0;
        }

        case BINARY_EXPR:
        {
            // Simple constant folding for basic expressions like [10 + 2]
            BinaryExpr* bin = expr.as(BinaryExpr);
            ulong left = eval_const_int(ctx, bin.left);
            ulong right = eval_const_int(ctx, bin.right);

            switch (bin.op)
            {
                case OP_ADD: return left + right;
                case OP_SUB: return left - right;
                case OP_MULT: return left * right;
                case OP_DIV: return right != 0 ? left / right : 0;
                default:
                    diagnostics::log_error("[Sema]: Unsupported operator in constant expression");
                    return 0;
            }
        }

        default:
            diagnostics::log_error("[Sema]: Non-constant expression used for array length");
            return 0;
    }
}
