module slate::sema;

import slate::core;
import slate::core::visitor;

//  module foo::bar;
//  import zoo;
//
//  module foo::bar::baz;
//  import xyz;
//
//  Section Scope 1 (range: lines 1-3)
//  ├── Imports: [zoo, std::core, ...]
//  └── Parent -> Module Scope (foo::bar)
//                   └── Builtin Scope
//
//  Section Scope 2 (range: lines 5-7)
//  ├── Imports: [xyz, std::core, ...]
//  └── Parent -> Module Scope (foo::bar::baz)
//                   └── Builtin Scope

const String[*] DEFAULT_IMPORTS = {
	"std::core",
	"std::core::string",
	"std::core::env"
};

fn void index_pass(SemaContext* ctx)
{
	foreach (SourceFile* sf : ctx.context.files.value_iter())
	{
		index_source_file(ctx, sf);
	}
}

fn void index_source_file(SemaContext* ctx, SourceFile* sf)
{
	Module* mod;
	ModuleDecl* mod_decl;
	Scope* section;
	bool has_module_header = false;
	bool section_enabled = false;

	foreach (Node* node : sf.ast.statements)
	{
		if (!node.is_valid()) continue;

		if (node.kind == MODULE_DECL)
		{
			has_module_header = true;
			mod_decl = node.as(ModuleDecl);
			PathAtom* atom = mod_decl.path.as(PathAtom);

			if (!is_node_enabled(ctx, mod_decl))
			{
				diagnostics::log_info("[index]: disabling module section: %s", atom.path.text);
                section_enabled = false;
                continue; // Skip rest of setup for this section
			}

			section_enabled = true;

			mod = mod::create(ctx.context, atom.path.text);
			ctx.current_module = mod;
			section = scope::create(ctx.alloc, node.range, mod.scope);

			foreach (String path : DEFAULT_IMPORTS)
            {
                scope::add_import(section, path);
            }

            continue;
		}

		if (!has_module_header)
        {
            diagnostics::error(ctx.context, node.range, "Expected module declaration before statements");
            return;
        }

        if (!section_enabled) continue;

        if (!is_node_enabled(ctx, (Decl*)node)) continue;

		ctx.node_scopes.set(node, section);
		mod::add_node(mod, node);
		mod_decl.nodes.push(node.id);

		switch (node.kind)
		{
			case IMPORT_DECL:
				ImportDecl* decl = node.as(ImportDecl);
				foreach (Node* path : decl.paths)
				{
					scope::add_import(section, path.as(PathAtom).path.text);
					diagnostics::log_info("Added import: %s", path.as(PathAtom).path.text);
				}
				break;
			case STRUCT_DECL:
				StructDecl* decl = node.as(StructDecl);
				index_struct_decl(ctx, mod.scope, decl);
				break;
			case FN_DECL:
				FnDecl* decl = node.as(FnDecl);
				index_function_decl(ctx, mod.scope, decl);
				break;
			case VAR_DECL:
				VarDecl* decl = node.as(VarDecl);
				index_var_decl(ctx, mod.scope, decl);
				break;
			case ENUM_DECL:
				// Handle Enum registration
				index_enum_decl(ctx, mod.scope, (Decl*)node);
				break;
			case TYPEDEF_DECL:
				TypedefDecl* decl = node.as(TypedefDecl);
				index_typedef_decl(ctx, mod.scope, decl);
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

	String qname = mod::get_qname(ctx.alloc, ctx.current_module, decl.name.text);

	Type* struct_type = lookup::register_type(
		ctx.context.lookup,
		ctx.alloc,
		qname,
		decl.name.text,
		decl,
		TYPE_STRUCT
	);

	decl.resolved_type = struct_type;
}

fn void index_typedef_decl(SemaContext* ctx, Scope* scope, TypedefDecl* td)
{
	Decl* decl = (Decl*)td;

	if (!scope::define(scope, decl.name.text, decl))
	{
		diagnostics::error(ctx.context, decl.range, "Redefinition of struct symbol in scope");
		return;
	}

	diagnostics::log_info("Defined typedef: %s", decl.name.text);

	String qname = mod::get_qname(ctx.alloc, ctx.current_module, decl.name.text);

	Type* typedef_type = lookup::register_type(
		ctx.context.lookup,
		ctx.alloc,
		qname,
		decl.name.text,
		decl,
		TYPE_ALIAS
	);

	decl.resolved_type = typedef_type;
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

	String qname = mod::get_qname(ctx.alloc, ctx.current_module, decl.name.text);

	Type* fn_type = lookup::register_type(
		ctx.context.lookup,
		ctx.alloc,
		qname,
		decl.name.text,
		decl,
		TYPE_FN
	);

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

	String qname = mod::get_qname(ctx.alloc, ctx.current_module, decl.name.text);

	Type* enum_type = lookup::register_type(
		ctx.context.lookup,
		ctx.alloc,
		qname,
		decl.name.text,
		decl,
		TYPE_ENUM
	);

	decl.resolved_type = enum_type;
}
