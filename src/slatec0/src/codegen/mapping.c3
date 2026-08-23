module slate::codegen;

import slate::core;
import std::collections;

import llvm;

fn LLVMTypeRef map_type(CodegenContext* gen, Type* type)
{
    if (type == null) return llvm::void_type_in_context(gen.llvm_ctx);

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
            // LLVM 15+ opaque pointers: all pointers are typed as `ptr` in context
            llvm_type = llvm::pointer_type_in_context(gen.llvm_ctx, 0);
            break;

        case TYPE_ARRAY:
        		LLVMTypeRef elem_type = map_type(gen, type.data.array.base);
            	llvm_type = llvm::array_type(elem_type, (uint)type.data.array.len);
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

        case TYPE_ENUM:
        	if (type.data.decl != null && type.data.decl.kind == ENUM_DECL)
            {
                EnumDecl* enum_decl = (EnumDecl*)type.data.decl;
                llvm_type = map_type(gen, enum_decl.resolved_type);
            }
            else
            {
                // Default enum backing type
                llvm_type = llvm::int_32_type_in_context(gen.llvm_ctx);
            }
            break;

        default:
            diagnostics::log_error("Unhandled type kind in codegen map_type");
            llvm_type = llvm::int_32_type_in_context(gen.llvm_ctx);
            break;
    }

    gen.type_cache.set(type, llvm_type);
    return llvm_type;
}
