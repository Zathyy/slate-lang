module slate::sema;

import slate::core;

import std::collections;

struct SemaContext
{
	CompilerContext* context;
	Allocator alloc;
	Scope* scope;
	String current_module;
	SourceFile* current_file;
	HashMap{NodeID, Type*} node_types;
}

fn SemaContext* create(CompilerContext* context)
{
	SemaContext* ctx = alloc::new(context.alloc, SemaContext);

	ctx.context = context;
	ctx.alloc = context.alloc;
	ctx.node_types.init(context.alloc);
	ctx.scope = scope::create(ctx.alloc, {});

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
		sf.sema.scope = scope::create(ctx.alloc, {});
	}

	// Pass 1: Index all declarations & resolve candidate signatures
    index_pass(ctx);

    resolve_decls_pass(ctx);

    //// Pass 3: Resolve global variable declarations & types
    //variable_pass(ctx);

    // Pass 4: Typecheck function bodies and local statements
    body_pass(ctx);
}
