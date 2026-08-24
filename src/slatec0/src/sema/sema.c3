module slate::sema;

import slate::core;

import std::collections;

struct SemaContext
{
	CompilerContext* context;
	Allocator alloc;
	String current_module;
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

fn void set_type(SemaContext* ctx, Node* node, Type* type)
{
    ctx.node_types.set(node.id, type);
}

fn Type*? get_type(SemaContext* ctx, Node* node)
{
    return ctx.node_types.get(node.id);
}

fn void run_pipeline(SemaContext* ctx)
{
	foreach (SourceFile* sf : ctx.context.files.value_iter())
	{
		Range range = source_file::get_range(sf);
		sf.sema.scope = scope::create(ctx.alloc, range);
	}

    index_pass(ctx);

    resolve_decls_pass(ctx);

    //variable_pass(ctx);

    body_pass(ctx);
}
