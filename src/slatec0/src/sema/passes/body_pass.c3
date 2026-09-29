module slate::sema;

import slate::core;
import slate::core::visitor;

fn void body_pass(SemaContext* ctx)
{
	foreach (Module* mod : ctx.context.modules.value_iter())
	{
		foreach (Node* statement : mod.nodes)
		{
			if (!statement || statement.kind != FN_DECL) continue;

			FnDecl* decl = statement.as(FnDecl);
			check_fn_body(ctx, ctx.node_scopes.get(statement) ?? mod.scope, decl);
		}
	}
}

fn void check_fn_body(SemaContext* ctx, Scope* parent_scope, FnDecl* fn_decl)
{
	Scope* fn_scope = scope::create(ctx.alloc, fn_decl.range, parent_scope);

	Type* old_return_type = ctx.transient.return_type;
	ctx.transient.return_type = fn_decl.ret_type != null
		? resolve_type(ctx, parent_scope, fn_decl.ret_type)
		: lookup::primitive_type(ctx.context.lookup, TYPE_VOID);

	foreach (Node* param_node : fn_decl.params)
	{
		VarDecl* param = param_node.as(VarDecl);

		if (param.var_flags.is_self_by_ref || param.var_flags.is_self)
		{
		}

		Type* param_type = resolve_type(ctx, parent_scope, param.type);
		param.resolved_type = param_type;

		if (!param.name) continue;

		if (Decl* existing = scope::define(fn_scope, param.name.text, (Decl*)param))
		{
			diagnostics::note(ctx.context, existing.range, "Previous use of '%s' was here", param.name.text);
			diagnostics::error(ctx.context, param.range, "Redefinition of parameter '%s'", param.name.text);
		}
	}

	if (fn_decl.body != null)
	{
		foreach (Node* node : fn_decl.body.as(CompoundStmt).statements)
		{
			Stmt* stmt = (Stmt*)node;
			check_stmt(ctx, fn_scope, stmt);
		}
	}

	ctx.transient.return_type = old_return_type;
}
