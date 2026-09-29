module slate::codegen;

import slate::core;
import std::collections;

import slate::sema::lookup;

import llvm;

fn LLVMTypeRef map_type(CodegenContext* gen, Type* type)
{
	assert(type != null, "Attempted to map a null type");

	if (LLVMTypeRef cached = gen.type_cache.get(type) ?? null)
	{
		return cached;
	}

	LLVMTypeRef llvm_type = null;

	switch (type.kind)
	{
		case TYPE_VOID:
			llvm_type = llvm::void_type_in_context(gen.llvm_ctx);
			break;
		case TYPE_BOOL:
			llvm_type = llvm::int_1_type_in_context(gen.llvm_ctx);
			break;
		case TYPE_I8:
		case TYPE_U8:
			llvm_type = llvm::int_8_type_in_context(gen.llvm_ctx);
			break;
		case TYPE_I16:
		case TYPE_U16:
			llvm_type = llvm::int_16_type_in_context(gen.llvm_ctx);
			break;
		case TYPE_I32:
		case TYPE_U32:
			llvm_type = llvm::int_32_type_in_context(gen.llvm_ctx);
			break;
		case TYPE_I64:
		case TYPE_U64:
		case TYPE_USIZE:
			llvm_type = llvm::int_64_type_in_context(gen.llvm_ctx);
			break;
		case TYPE_F32:
			llvm_type = llvm::float_type_in_context(gen.llvm_ctx);
			break;
		case TYPE_F64:
			llvm_type = llvm::double_type_in_context(gen.llvm_ctx);
			break;

		case TYPE_POINTER:
		case TYPE_REF:
			// LLVM 15+ opaque pointers: all pointers are typed as `ptr` in context
			llvm_type = llvm::pointer_type_in_context(gen.llvm_ctx, 0);
			break;
		case TYPE_ARRAY:
				LLVMTypeRef elem_type = map_type(gen, type.data.array.base);
				llvm_type = llvm::array_type(elem_type, (uint)type.data.array.len);
			break;
		case TYPE_ALIAS:
		case TYPE_ENUM:
			llvm_type = map_type(gen, type.canonical);
			break;
		case TYPE_SLICE:
			if (gen.slice_llvm_type != null)
            {
                llvm_type = gen.slice_llvm_type;
            }
            else
            {
                llvm_type = llvm::struct_create_named(gen.llvm_ctx, "Slice");
                LLVMTypeRef[*] fields = {
                    llvm::pointer_type_in_context(gen.llvm_ctx, 0),
                    lookup::primitive_type(gen.context.lookup, TYPE_USIZE).llvm_type
                };
                llvm::struct_set_body(llvm_type, &fields, 2, 0);
                gen.slice_llvm_type = llvm_type;
            }
            break;
		case TYPE_STRUCT:
			if (type.data.decl != null && type.data.decl.kind == STRUCT_DECL)
			{
				llvm_type = emit_struct_type(gen, (StructDecl*)type.data.decl);
			}
			else
			{
				// Anonymous or empty struct fall-back
				llvm_type = llvm::struct_type_in_context(gen.llvm_ctx, null, 0, 0);
			}
			break;
		case TYPE_FN:
		{
		    FnDecl* func = type.data.decl.as(FnDecl);

		    Type* ret_resolved_type = (func.ret_type != null) ? func.ret_type.resolved_type : null;

		    LLVMTypeRef ret_type = (func.ret_type != null && func.ret_type.resolved_type != null)
		        ? map_type(gen, func.ret_type.resolved_type)
		        : llvm::void_type_in_context(gen.llvm_ctx);

		    int param_count = func.params.len;
		    LLVMTypeRef* param_types = alloc::alloc_array(gen.alloc, LLVMTypeRef, param_count);

		    int actual_count = 0;
		    for (int i = 0; i < param_count; i++)
		    {
		        VarDecl* param = func.params[i].as(VarDecl);
		        if (param.var_flags.is_variadic) continue;

		        diagnostics::log_info("VarDecl: %s", param.name.text);
		        param_types[actual_count++] = map_type(gen, param.resolved_type);
		    }

		    llvm_type = llvm::function_type(ret_type, param_types, (uint)actual_count, (LLVMBool)func.is_variadic);
		    break;
		}
		default:
			diagnostics::log_error("Unhandled type kind in codegen map_type: %s", type.kind.description);
			llvm_type = llvm::int_32_type_in_context(gen.llvm_ctx);
			break;
	}

	if (type.is_optional && type.kind != TYPE_POINTER)
    {
        LLVMTypeRef[2] opt_fields = {
            llvm_type,
            llvm::int_1_type_in_context(gen.llvm_ctx)
        };
        llvm_type = llvm::struct_type_in_context(gen.llvm_ctx, &opt_fields, 2, 0);
    }

	gen.type_cache.set(type, llvm_type);
	return llvm_type;
}
