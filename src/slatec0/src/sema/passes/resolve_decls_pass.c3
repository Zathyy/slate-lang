module slate::sema;

import slate::core;
import slate::core::visitor;

fn void resolve_decls_pass(SemaContext* ctx)
{
	foreach (Module* mod : ctx.context.modules.value_iter())
	{
		foreach (Node* node : mod.nodes)
		{
			Scope* scope = ctx.node_scopes.get(node) ?? mod.scope;

			switch (node.kind)
			{
				case STRUCT_DECL:
				{
					StructDecl* s_decl = node.as(StructDecl);
					foreach (Node* field_node : s_decl.fields)
					{
						VarDecl* field = field_node.as(VarDecl);
						field.resolved_type = resolve_type(ctx, scope, field.type);
						set_type(ctx, field_node, field.resolved_type);
					}
					s_decl.resolved_type.status = RESOLVED;
					break;
				}
				case TYPEDEF_DECL:
				{
					TypedefDecl* t_decl = node.as(TypedefDecl);
					Type* target_type = resolve_type(ctx, scope, t_decl.base_type);

					if (target_type != null && t_decl.resolved_type != null)
				    {
				        t_decl.resolved_type.canonical = target_type.canonical != null
				            ? target_type.canonical
				            : target_type;

				        t_decl.resolved_type.status = RESOLVED;
				        set_type(ctx, t_decl, t_decl.resolved_type);
				    }
					break;
				}
				case ENUM_DECL:
				{
					EnumDecl* e_decl = node.as(EnumDecl);

				    Type* underlying = e_decl.backing_type != null
				        ? resolve_type(ctx, scope, e_decl.backing_type)
				        : lookup::primitive_type(ctx.context.lookup, TYPE_I32);

				    if (!underlying)
				    {
				        diagnostics::error(ctx.context, e_decl.range, "Unknown backing type for enum %s", e_decl.name.text);
				    }

				    if (e_decl.resolved_type != null)
				    {
				        e_decl.resolved_type.size = underlying.size;
				        e_decl.resolved_type.alignment = underlying.alignment;
				        e_decl.resolved_type.llvm_type = underlying.llvm_type;

				        e_decl.resolved_type.canonical = underlying.canonical != null
				            ? underlying.canonical
				            : underlying;

				        e_decl.resolved_type.status = RESOLVED;
				        set_type(ctx, e_decl, e_decl.resolved_type);
				    }

				    foreach (Node* entry_node : e_decl.variants)
				    {
				        set_type(ctx, entry_node, e_decl.resolved_type);
				    }
				    break;
				}
				default:
			}
		}
	}

	foreach (Module* mod : ctx.context.modules.value_iter())
	{
		foreach (Node* node : mod.nodes)
		{
			if (node.kind == FN_DECL)
			{
				FnDecl* fn_decl = node.as(FnDecl);
				Scope* fn_scope = ctx.node_scopes.get(node) ?? mod.scope;

				if (fn_decl.ret_type)
				{
					Expr* expr = (Expr*)fn_decl.ret_type;
					expr.resolved_type = resolve_type(ctx, fn_scope, fn_decl.ret_type);
					set_type(ctx, expr, expr.resolved_type);
				}

				foreach (Node* param_node : fn_decl.params)
				{
					VarDecl* param = param_node.as(VarDecl);
					param.resolved_type = resolve_type(ctx, fn_scope, param.type);

					if (!param.var_flags.is_variadic && !param.resolved_type)
					{
						diagnostics::error(ctx.context, param.type.range, "Param type not found: %s", ast::raw_type_identifier(param.type) ?? "");
					}
					set_type(ctx, (Node*)param, param.resolved_type);
				}
			}
		}
	}
}
