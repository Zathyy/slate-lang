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
	Module* ast_mod;

	LLVMContextRef llvm_ctx;
	LLVMModuleRef mod;
	LLVMBuilderRef builder;
	LLVMTargetDataRef target_data;

	ValueScope* current_scope;
	HashMap{void*, LLVMTypeRef} type_cache;
	HashMap{void*, LLVMTypeRef} locals;
	LLVMTypeRef slice_llvm_type;

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
	ctx.target_data = llvm::create_target_data_layout(context.llvm_target);

	ctx.type_cache.init(ctx.alloc);
	ctx.loop_stack.init(ctx.alloc);
	ctx.locals.init(ctx.alloc);

	push_scope(ctx);

	return ctx;
}

fn bool emit_module(CodegenContext* gen, Module* ast_mod)
{
	LLVMModuleRef llvm_mod = llvm::module_create_with_name_in_context(
		(CChar*)ast_mod.name.ptr,
		gen.llvm_ctx
	);
	CChar* layout_str = llvm::copy_string_rep_of_target_data(gen.target_data);
	llvm::set_data_layout(llvm_mod, layout_str);
	llvm::dispose_message(layout_str);

	ast_mod.llvm_module = llvm_mod;
	gen.mod = llvm_mod;
	gen.ast_mod = ast_mod;

	foreach (Node* node : ast_mod.nodes)
	{
		switch (node.kind)
		{
			case STRUCT_DECL:
				emit_struct_type(gen, node.as(StructDecl));
				break;
			case TYPEDEF_DECL:
				emit_typedef(gen, node.as(TypedefDecl));
				break;
			default:
		}
	}

	foreach (Node* node : ast_mod.nodes)
	{
		switch (node.kind)
		{
			case FN_DECL:
				emit_function(gen, (FnDecl*)node);
				break;
			default:
		}
	}

	//llvm::dump_module(gen.mod);

	CChar* error_msg = null;
	if (llvm::verify_module(gen.mod, RETURN_STATUS_ACTION, &error_msg))
	{
		diagnostics::log_error("LLVM Verification Failed: %s", (ZString)error_msg);
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

<*
 Emits an anonymous constant global string array for compile-time initializers.
*>
fn LLVMValueRef emit_global_string_const(
    CodegenContext* cg,
    String str,
    CChar* name = ".str") => @pool()
{
    LLVMContextRef ctx = cg.llvm_ctx;

    str = str.treplace("\"", "");
    String final_string = string::format(cg.alloc, "%s.str", cg.ast_mod.name.treplace("::", "."));

    // Creates an i8 array constant with a trailing null terminator (\0)
    LLVMValueRef str_val = llvm::const_string_in_context(ctx, (CChar*)str.ptr, (uint)str.len, 0);

    LLVMTypeRef str_type = llvm::array_type(llvm::int_8_type_in_context(ctx), (uint)str.len + 1);
    LLVMValueRef global_var = llvm::add_global(cg.mod, str_type, (CChar*)final_string.ptr);

    llvm::set_initializer(global_var, str_val);
    llvm::set_global_constant(global_var, 1);
    llvm::set_linkage(global_var, PRIVATE_LINKAGE);
    llvm::set_unnamed_addr(global_var, 1); // Enables LLVM string deduplication/merging

    // Cast [N x i8]* to i8* pointer for String slice 'ptr' field
    LLVMTypeRef i8_ptr_t = llvm::pointer_type(llvm::int_8_type_in_context(ctx), 0);
    return llvm::const_bit_cast(global_var, i8_ptr_t);
}

fn LLVMValueRef get_or_add_function(CodegenContext* cg, Decl* decl, String name)
{
    LLVMValueRef func = llvm::get_named_function(cg.mod, (CChar*)name.ptr);
    if (func == null)
    {
        LLVMTypeRef fn_type = map_type(cg, decl.resolved_type);
        func = llvm::add_function(cg.mod, (CChar*)name.ptr, fn_type);
    }
    return func;
}
