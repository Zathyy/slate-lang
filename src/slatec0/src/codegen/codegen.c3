module slate::codegen;

import slate::core;
import slate::core::ast;

import std::collections;

import llvm;

struct LoopBlocks
{
    LLVMBasicBlockRef break_bb;
    LLVMBasicBlockRef continue_bb;
}

struct ValueScope
{
    ValueScope* parent;
    HashMap{void*, LLVMValueRef} bindings;
}

struct CodegenContext
{
	Allocator alloc;
	CompilerContext* context;

	LLVMContextRef llvm_ctx;
    LLVMModuleRef mod;
    LLVMBuilderRef builder;
    LLVMTargetDataRef target_data;

    ValueScope* current_scope;
    HashMap{void*, LLVMTypeRef} type_cache;

    List{LoopBlocks} loop_stack;

    // Current Function State
    LLVMValueRef current_fn;
    LLVMBasicBlockRef current_block;
}

fn CodegenContext* create(CompilerContext* context)
{
	CodegenContext* ctx = alloc::new(context.alloc, CodegenContext);

	ctx.alloc = context.alloc;
	ctx.context = context;

	ctx.llvm_ctx = context.llvm_context;
	ctx.builder = llvm::create_builder_in_context(ctx.llvm_ctx);

	ctx.type_cache.init(ctx.alloc);
    ctx.loop_stack.init(ctx.alloc);

	push_scope(ctx);

	return ctx;
}

fn bool emit_module(CodegenContext* gen, Module* ast_mod)
{
	LLVMModuleRef llvm_mod = llvm::module_create_with_name_in_context(
        (CChar*)ast_mod.name.ptr,
        gen.llvm_ctx
    );

    ast_mod.llvm_module = llvm_mod;
    gen.mod = llvm_mod;

    foreach (Node* node : ast_mod.nodes)
    {
        switch (node.kind)
        {
        	case FN_DECL:
         		emit_function(gen, (FnDecl*)node);
           		break;
            case STRUCT_DECL:
           		emit_struct_type(gen, node.as(StructDecl));
             	break;
            default:
        }
    }

    CChar* error_msg = null;
    if (llvm::verify_module(gen.mod, RETURN_STATUS_ACTION, &error_msg))
    {
        diagnostics::log_error("LLVM Verification Failed: %s", error_msg);
        llvm::dispose_message(error_msg);
        return false;
    }
    return true;
}

fn void push_scope(CodegenContext* gen)
{
    ValueScope* scope = alloc::new(gen.alloc, ValueScope);
    scope.parent = gen.current_scope;
    scope.bindings.init(gen.alloc);
    gen.current_scope = scope;
}

fn void pop_scope(CodegenContext* gen)
{
    if (gen.current_scope == null) return;
    gen.current_scope = gen.current_scope.parent;
}

fn LLVMValueRef get_value(CodegenContext* gen, Decl* decl)
{
    ValueScope* curr = gen.current_scope;
    while (curr != null)
    {
        if (LLVMValueRef val = curr.bindings.get(decl) ?? null)
        {
            return val;
        }
        curr = curr.parent;
    }
    return null;
}

fn void bind_value(CodegenContext* gen, Decl* decl, LLVMValueRef val)
{
    gen.current_scope.bindings.set(decl, val);
}
