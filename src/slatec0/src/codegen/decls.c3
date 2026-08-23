module slate::codegen;

import slate::core;
import std::collections;

import llvm;

fn LLVMTypeRef emit_struct_type(CodegenContext* gen, StructDecl* s_decl)
{
	if (s_decl.resolved_type.llvm_type != null)
    {
        return s_decl.resolved_type.llvm_type;
    }

	CChar* c_name = (CChar*)s_decl.name.text.ptr;

	LLVMTypeRef struct_type = llvm::struct_create_named(gen.llvm_ctx, c_name);

	if (s_decl.resolved_type != null)
    {
    	s_decl.resolved_type.llvm_type = struct_type;
        gen.type_cache.set(s_decl.resolved_type, struct_type);
    }

    List{LLVMTypeRef} field_types;
    field_types.init(gen.alloc);

    foreach (Node* field_node : s_decl.fields)
    {
   		VarDecl* field = field_node.as(VarDecl);
    	assert(field.resolved_type);
        field_types.push(map_type(gen, field.resolved_type));
    }

    llvm::struct_set_body(struct_type, field_types.entries, (uint)field_types.len(), 0);

    return struct_type;
}

fn bool emit_function(CodegenContext* gen, FnDecl* fn_decl)
{
    String fn_name = fn_decl.name.text;
    CChar* c_fn_name = (CChar*)fn_name.ptr;

    Expr* ret_expr = (Expr*)fn_decl.ret_type;
    LLVMTypeRef ret_type = map_type(gen, ret_expr != null ? ret_expr.resolved_type : null);

    List{LLVMTypeRef} param_types;
    param_types.init(gen.alloc);

    foreach (Node* param_node : fn_decl.params)
    {
   		VarDecl* param = param_node.as(VarDecl);
        param_types.push(map_type(gen, param.resolved_type));
    }

    LLVMTypeRef fn_type = llvm::function_type(
        ret_type,
        param_types.entries,
        (uint)param_types.len(),
        0
    );

    LLVMValueRef fn_val = llvm::add_function(gen.mod, c_fn_name, fn_type);

    if (fn_decl.flags.is_extern || fn_decl.body == null)
    {
        llvm::set_linkage(fn_val, EXTERNAL_LINKAGE);
        return true;
    }

    gen.current_fn = fn_val;

    LLVMBasicBlockRef entry_bb = llvm::append_basic_block_in_context(
        gen.llvm_ctx,
        fn_val,
        "entry"
    );
    llvm::position_builder_at_end(gen.builder, entry_bb);
    gen.current_block = entry_bb;

    push_scope(gen);
    defer pop_scope(gen);

    for (uint i = 0; i < (uint)param_types.len(); i++)
    {
        LLVMValueRef param_val = llvm::get_param(fn_val, i);
        VarDecl* param_decl = fn_decl.params[i].as(VarDecl);
        bind_value(gen, (Decl*)param_decl, param_val);
    }

    if (fn_decl.body != null)
    {
        // emit_statement(gen, fn_decl.body);
    }

    LLVMValueRef last_inst = llvm::get_last_instruction(entry_bb);
    if (last_inst == null || !llvm::is_a_terminator_inst(last_inst))
    {
        if (fn_name == "main")
        {
            LLVMValueRef zero = llvm::const_int(
                llvm::int_32_type_in_context(gen.llvm_ctx),
                0,
                0
            );
            llvm::build_ret(gen.builder, zero);
        }
        else if (ret_type == llvm::void_type_in_context(gen.llvm_ctx))
        {
            llvm::build_ret_void(gen.builder);
        }
        else
        {
            LLVMValueRef default_val = llvm::const_null(ret_type);
            llvm::build_ret(gen.builder, default_val);
        }
    }

    return true;
}
