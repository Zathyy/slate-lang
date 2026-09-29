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

	String mod_name = gen.ast_mod.name.replace(gen.alloc, "::", ".");
	String full_name = string::format(gen.alloc, "%s.%s", mod_name, s_decl.name.text);

	LLVMTypeRef struct_type = llvm::struct_create_named(gen.llvm_ctx, (CChar*)full_name.ptr);

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

fn void emit_typedef(CodegenContext* gen, TypedefDecl* decl)
{
    if (decl.resolved_type == null)
    {
        return;
    }

    if (decl.resolved_type.llvm_type != null)
    {
        return;
    }

    LLVMTypeRef mapped_type = map_type(gen, decl.resolved_type);

    decl.resolved_type.llvm_type = mapped_type;
    gen.type_cache.set(decl.resolved_type, mapped_type);
}


fn bool emit_function(CodegenContext* gen, FnDecl* fn_decl)
{
	String mod_name = gen.ast_mod.name.replace(gen.alloc, "::", "_");
	String full_name @noinit;
	if (fn_decl.method_type)
	{
		full_name = string::format(gen.alloc, "%s_%s_%s", mod_name, ast::raw_type_identifier(fn_decl.method_type)!!, fn_decl.name.text);
	}
	else
	{
		full_name = string::format(gen.alloc, "%s_%s", mod_name, fn_decl.name.text);
	}

	if (fn_decl.name.text == "main" || fn_decl.flags.is_extern)
	{
		full_name = fn_decl.name.text;
	}

	gen.locals.clear();

	LLVMTypeRef fn_type = map_type(gen, fn_decl.resolved_type);
	LLVMValueRef fn_val = llvm::add_function(gen.mod, (CChar*)full_name.ptr, fn_type);

	LLVMAttributeRef nonnull_attr = llvm::create_enum_attribute(
        gen.llvm_ctx,
        llvm::get_enum_attribute_kind_for_name("nonnull", 7),
        0
    );
    LLVMAttributeRef noundef_attr = llvm::create_enum_attribute(
        gen.llvm_ctx,
        llvm::get_enum_attribute_kind_for_name("noundef", 7),
        0
    );

	if (fn_decl.ret_type != null && fn_decl.ret_type.resolved_type != null && fn_decl.ret_type.resolved_type.kind == TYPE_REF)
	{
	    llvm::add_attribute_at_index(fn_val, 0, nonnull_attr);
	    llvm::add_attribute_at_index(fn_val, 0, noundef_attr);
	}

	uint llvm_param_idx = 1;
    foreach (Node* param_node : fn_decl.params)
    {
        VarDecl* param = param_node.as(VarDecl);
        if (param.var_flags.is_variadic) continue;

        if (param.resolved_type != null &&
            param.resolved_type.kind == TYPE_REF)
        {
            llvm::add_attribute_at_index(fn_val, llvm_param_idx, nonnull_attr);
            llvm::add_attribute_at_index(fn_val, llvm_param_idx, noundef_attr);
        }
        llvm_param_idx++;
    }

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

	uint param_idx = 0;
	foreach (Node* param_node : fn_decl.params)
	{
		VarDecl* param_decl = param_node.as(VarDecl);
		if (param_decl.var_flags.is_variadic) continue;
		uint param_align = param_decl.resolved_type.alignment;
		LLVMValueRef param_val = llvm::get_param(fn_val, param_idx);
		LLVMTypeRef param_llvm_type = map_type(gen, param_decl.resolved_type);

		llvm::set_value_name(param_val, (CChar*)param_decl.name.text.ptr);
		diagnostics::log_warn("TYPE %s ALIGN: %d", param_decl.resolved_type.name, param_align);
		LLVMValueRef alloca_ptr = llvm::build_alloca(
            gen.builder,
            param_llvm_type,
            (CChar*)param_decl.name.text.ptr
        );

        LLVMTypeRef store_ptr = llvm::build_store(gen.builder, param_val, alloca_ptr);

        gen.locals.set(param_node, alloca_ptr);

		bind_value(gen, (Decl*)param_decl, alloca_ptr);
		param_idx++;
	}

	if (fn_decl.body != null)
	{
		emit_statement(gen, (Stmt*)fn_decl.body);
	}

	LLVMBasicBlockRef active_bb = llvm::get_insert_block(gen.builder);
	LLVMValueRef last_inst = llvm::get_last_instruction(active_bb);

	if (last_inst == null || !llvm::is_a_terminator_inst(last_inst))
	{
		if (fn_decl.name.text == "main")
		{
			LLVMValueRef zero = llvm::const_int(
				llvm::int_32_type_in_context(gen.llvm_ctx),
				0,
				0
			);
			llvm::build_ret(gen.builder, zero);
		}
		else if (llvm::get_return_type(fn_type) == llvm::void_type_in_context(gen.llvm_ctx))
		{
			llvm::build_ret_void(gen.builder);
		}
		else
		{
			LLVMValueRef default_val = llvm::const_null(llvm::get_return_type(fn_type));
			llvm::build_ret(gen.builder, default_val);
		}
	}

	return true;
}
