module slate::sema;

import slate::core;

import std::collections;

struct SemaContext
{
	CompilerContext* context;
	Allocator alloc;
	Module* current_module;
	SourceFile* current_file;
	HashMap{NodeID, Type*} node_types;
	HashMap{void*, Scope*} node_scopes;

	struct transient
	{
		Type* return_type;
		Scope* current_scope;
	}
}

fn SemaContext* create(CompilerContext* context)
{
	SemaContext* ctx = alloc::new(context.alloc, SemaContext);

	ctx.context = context;
	ctx.alloc = context.alloc;
	ctx.node_types.init(context.alloc);
	ctx.node_scopes.init(context.alloc);

	return ctx;
}
