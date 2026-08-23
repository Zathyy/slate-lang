module slate::sema;

import slate::core;
import slate::core::visitor;

fn void resolve_decls_pass(SemaContext* ctx)
{
    foreach (Module* mod : ctx.context.modules.value_iter())
    {
  		diagnostics::log_debug("[resolve_decls_pass]: Module: %s - num of nodes: %s", mod.name, mod.nodes.len());

        foreach (Node* node : mod.nodes)
        {
            switch (node.kind)
            {
                case STRUCT_DECL:
                {
                    StructDecl* s_decl = node.as(StructDecl);
                    foreach (Node* field_node : s_decl.fields)
                    {
                        VarDecl* field = field_node.as(VarDecl);
                        field.resolved_type = resolve_type(ctx, field.type);
                        set_type(ctx, field_node, field.resolved_type);
                    }
                    s_decl.resolved_type.status = RESOLVED;
                    break;
                }
                case FN_DECL:
                {
                    FnDecl* fn_decl = node.as(FnDecl);
                    if (fn_decl.ret_type)
                    {
                    	Expr* expr = (Expr*)fn_decl.ret_type;
                    	expr.resolved_type = resolve_type(ctx, fn_decl.ret_type);
                     	set_type(ctx, expr, expr.resolved_type);
                    }

                    foreach (Node* param_node : fn_decl.params)
                    {
                   		VarDecl* param = param_node.as(VarDecl);
                    	if (!param.type) continue;
                        param.resolved_type = resolve_type(ctx, param.type);
                        set_type(ctx, (Node*)param, param.resolved_type);
                    }
                    break;
                }
                default:
            }
        }
    }
}
