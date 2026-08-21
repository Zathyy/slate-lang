module slate::sema;

import slate::core;
import slate::core::visitor;

const String[] DEFAULT_IMPORTS = {
	"std::core",
	"std::core::env"
};

fn void index_pass(SemaContext* ctx)
{
	foreach (SourceFile* sf : ctx.context.files.value_iter())
	{
		ctx.context.current_source_file = sf;
		index_source_file(ctx, sf);
	}
}

fn void index_source_file(SemaContext* ctx, SourceFile* sf)
{
	Scope* global_scope = sf.sema.scope;

	foreach (String path : DEFAULT_IMPORTS)
	{
		scope::add_import(global_scope, path);
		diagnostics::log_info("Added import: %s", path);
	}

	Module* mod;

	foreach (Node* node : sf.ast.statements)
	{
		if (!node.is_valid()) continue;

		if (!mod && node.kind != MODULE_DECL)
		{
			diagnostics::error(ctx.context, node.range, "Expected module to be the first node except for attributes");
			return;
		}

		if (node.kind == MODULE_DECL)
		{
			ModuleDecl* decl = node.as(ModuleDecl);
			PathAtom* atom = decl.path.as(PathAtom);
			mod = mod::create(ctx.context, atom.path.text);
		}

		mod::add_node(mod, node);

		switch (node.kind)
		{
			case IMPORT_DECL:
				ImportDecl* decl = node.as(ImportDecl);
				foreach (Node* path : decl.paths)
				{
					scope::add_import(global_scope, path.as(PathAtom).path.text);
					diagnostics::log_info("Added import: %s", path.as(PathAtom).path.text);
				}
				break;
			case STRUCT_DECL:
				StructDecl* decl = node.as(StructDecl);
				index_struct_decl(ctx, global_scope, decl);
				break;
			case FN_DECL:
				FnDecl* decl = node.as(FnDecl);
				index_function_decl(ctx, global_scope, decl);
				break;
			case VAR_DECL:
				VarDecl* decl = node.as(VarDecl);
				index_var_decl(ctx, global_scope, decl);
				break;
			case ENUM_DECL:
				// Handle Enum registration
				index_enum_decl(ctx, global_scope, (Decl*)node);
				break;
			default:
				break;
		}
	}
}

fn void index_struct_decl(SemaContext* ctx, Scope* scope, StructDecl* s)
{
	Decl* decl = (Decl*)s;

	if (!scope::define(scope, decl.name.text, decl))
	{
		diagnostics::error(ctx.context, decl.range, "Redefinition of struct symbol in scope");
		return;
	}

	diagnostics::log_info("Defined struct: %s", decl.name.text);

	Type* struct_type = lookup::register_type(
		ctx.context.lookup,
		ctx.alloc,
		decl.name.text,
		decl,
		TYPE_STRUCT
	);

	decl.resolved_type = struct_type;
}

fn void index_function_decl(SemaContext* ctx, Scope* scope, FnDecl* f)
{
	Decl* decl = (Decl*)f;

	if (!scope::define(scope, decl.name.text, decl))
	{
		diagnostics::error(ctx.context, f.range, "Redefinition of function symbol in scope");
		return;
	}

	diagnostics::log_info("Defined function: %s", decl.name.text);

	Type* fn_type = alloc::new(ctx.context.alloc, Type);
	fn_type.kind = TYPE_FN;
	fn_type.status = UNRESOLVED;
	fn_type.name = decl.name.text;
	fn_type.data.decl = decl;

	decl.resolved_type = fn_type;
}

fn void index_var_decl(SemaContext* ctx, Scope* scope, VarDecl* v)
{
	Decl* decl = (Decl*)v;

	if (!scope::define(scope, decl.name.text, decl))
	{
		diagnostics::error(ctx.context, decl.range, "Redefinition of global variable symbol in scope");
		return;
	}

	diagnostics::log_info("Defined var: %s", decl.name.text);
}

fn void index_enum_decl(SemaContext* ctx, Scope* scope, Decl* decl)
{
	if (!scope::define(scope, decl.name.text, decl))
	{
		diagnostics::error(ctx.context, decl.range, "Redefinition of enum symbol in scope");
		return;
	}

	diagnostics::log_info("Defined enum: %s", decl.name.text);

	Type* enum_type = lookup::register_type(
		ctx.context.lookup,
		ctx.alloc,
		decl.name.text,
		decl,
		TYPE_ENUM
	);

	decl.resolved_type = enum_type;
}
