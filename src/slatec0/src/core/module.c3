module slate::core::mod;

import slate::core::ast;
import slate::core::diagnostics;

import slate::sema::scope;

import std::io;

import llvm;

<*
 @param [&in] ctx
 @param [in] name
 @require name.len > 0
*>
fn Module* create(CompilerContext* ctx, String name)
{
	if (try Module* mod = ctx.modules.get(name))
	{
		return mod;
	}

	Module* mod = alloc::new(ctx.alloc, Module);

	diagnostics::log_debug("Created module: %s", name);

	mod.name = name;
	mod.nodes.init(ctx.alloc);
	mod.module_decls.init(ctx.alloc);
	mod.node_map.init(ctx.alloc);
	mod.scope = scope::create(ctx.alloc, {});

	ctx.modules.set(name, mod);

	return mod;
}

fn void add_node(Module* mod, Node* node)
{
	mod.nodes.push(node);
	mod.node_map.set(node.id, node);

	if (node.kind == MODULE_DECL)
	{
		mod.module_decls.push(node.as(ModuleDecl));
	}
}

<*
 Returns the fully qualified name of a symbol relative to this module.
 e.g., mod.get_qname("WIN32") -> "std::core::env::WIN32"
*>
fn String get_qname(Allocator alloc, Module* mod, String symbol_name)
{
    if (mod.name.len == 0) return symbol_name;
    return string::format(alloc, "%s::%s", mod.name, symbol_name);
}

<*
 Finds a top-level Node/Decl in this module by its short name.
*>
fn Decl* Module.find_decl(Module* mod, String name)
{
    foreach (Node* node : mod.nodes)
    {
    	if (!node) continue;
        if (node.is_decl())
        {
            Decl* decl = (Decl*)node;
            if (!decl.name) continue;
            if (decl.name.text == name) return (Decl*)node;
        }
    }
    return null;
}
