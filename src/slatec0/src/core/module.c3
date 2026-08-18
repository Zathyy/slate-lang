module slate::core::mod;

import slate::core::ast;
import slate::core::diagnostics;

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

	mod.llvm_module = llvm::module_create_with_name((CChar*)name.ptr);

	mod.name = name;
	mod.nodes.init(ctx.alloc);
	mod.module_decls.init(ctx.alloc);
	mod.node_map.init(ctx.alloc);

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
