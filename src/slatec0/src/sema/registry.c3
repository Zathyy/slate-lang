module slate::sema::registry;
import slate::sema::lookup;
import slate::core;
import std::collections;
import std::io;

import llvm;

fn Registry* create(Allocator alloc)
{
	Registry* registry = alloc::new(alloc, Registry);

	registry.functions.init(alloc);
	registry.globals.init(alloc);
	registry.types.init(alloc);

	return registry;
}

fn void register(CompilerContext* context, SourceFile* sf) => @pool()
{
	Module* current_mod;

	foreach (Node* statement : sf.ast.statements)
	{
		if (!statement) continue;
		if (statement.kind == MODULE_DECL)
		{
			ModuleDecl* mod_decl = statement.as(ModuleDecl);
			PathAtom* path = mod_decl.path.as(PathAtom);
			current_mod = mod::create(context, path.path.text);
		}

		if (current_mod == null)
		{
			Path? path = path::tnew(sf.path);
			if (catch err = path)
			{
				diagnostics::log_error("Failed to infer module name: %s", err);
				return;
			}
			current_mod = mod::create(context, path.basename());
		}

		register_and_dispatch(context, current_mod, statement);
	}
}

fn void register_and_dispatch(CompilerContext* context, Module* mod, Node* node)
{
	mod::add_node(mod, node);

	switch (node.kind)
	{
		case STRUCT_DECL:
		case ENUM_DECL:
		case TYPEDEF_DECL:
			register_type(context, mod, node);
			break;
		case FN_DECL:
			register_function(context, mod, node);
			break;
		case VAR_DECL:
			assert(node.as(VarDecl).var_kind == VarDeclKind.VAR_GLOBAL);
			register_global(context, mod, node);
		default:
			break;
	}
}

fn void register_type(CompilerContext* context, Module* mod, Node* node)
{
	Ident* name;
	LLVMTypeRef llvm_type = null;

	switch (node.kind)
	{
		case STRUCT_DECL:
		{
			StructDecl* decl = node.as(StructDecl);
			name = decl.name;
			llvm_type = llvm::struct_create_named(llvm::get_global_context(), (CChar*)name.text.ptr);
		}
		case ENUM_DECL:
		{
			EnumDecl* decl = node.as(EnumDecl);
			name = decl.name;
			llvm_type = llvm::int_32_type_in_context(llvm::get_global_context());
		}
		case TYPEDEF_DECL:
		{
			TypedefDecl* decl = node.as(TypedefDecl);
			name = decl.name;
			llvm_type = null;
		}
		default:
			return;
	}

	if (!name)
	{
		diagnostics::log_error("registry::register_type - name is null");
		return;
	}

	String qname = string::format(context.alloc, "%s::%s", mod.name, name.text);

	TypeInfo* type_info = alloc::new(context.alloc, TypeInfo);
	type_info.mod = mod.name;
	type_info.node = node;

	TypeInfo* existing_head = context.registry.types.get(qname) ?? null;
	type_info.next = existing_head;

	diagnostics::log_debug("[Registry]: registered type: %s", qname);

	context.registry.types.set(qname, type_info);
	if (llvm_type != null)
    {
        lookup::register_type(context.lookup, context.alloc, qname, node, llvm_type);
    }
}

<*
 The underlying type will be resolved later, since it depends on everything else being registered
*>
fn void register_global(CompilerContext* context, Module* mod, Node* node)
{
    VarDecl* decl = node.as(VarDecl);
    if (!decl.name)
    {
        diagnostics::log_error("registry::register_global - var name is null");
        return;
    }

    String qname = string::format(context.alloc, "%s::%s", mod.name, decl.name.text);

    VarInfo* var_info = alloc::new(context.alloc, VarInfo);
    var_info.mod = mod.name;
    var_info.node = node;

    VarInfo* existing_head = context.registry.globals.get(qname) ?? null;
    var_info.next = existing_head;

    diagnostics::log_debug("[Registry]: registered global var symbol: %s", qname);

    context.registry.globals.set(qname, var_info);
}

fn void register_function(CompilerContext* context, Module* mod, Node* node)
{
	FnDecl* decl = node.as(FnDecl);
	if (!decl.name)
	{
		diagnostics::log_error("registry::register_function - function name is null");
		return;
	}

	String qname = string::format(context.alloc, "%s::%s", mod.name, decl.name.text);

	FunctionInfo* function_info = alloc::new(context.alloc, FunctionInfo);
	function_info.mod = mod.name;
	function_info.node = node;

	FunctionInfo* existing_head = context.registry.functions.get(qname) ?? null;
	function_info.next = existing_head;

	diagnostics::log_debug("[Registry]: registered fn: %s", qname);

	context.registry.functions.set(qname, function_info);
}

<*
 Find the specified function using qualifief name, e.g. foo::bar
*>
fn FunctionInfo* get_function(CompilerContext* context, String name)
{
	return context.registry.functions.get(name) ?? null;
}

<*
 Find the specified function using qualifief name, e.g. foo::bar
*>
fn TypeInfo* get_type(CompilerContext* context, String name)
{
	return context.registry.types.get(name) ?? null;
}
