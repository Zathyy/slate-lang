module slate::codegen;

import slate::core;
import std::collections;

import llvm;

fn LLVMValueRef emit_expr(CodegenContext* cg, Expr* expr)
{
	switch (expr.kind)
	{
		case BINARY_EXPR:
		{
			BinaryExpr* bin = expr.as(BinaryExpr);
			Expr* lhs_expr = (Expr*)bin.left;
			Expr* rhs_expr = (Expr*)bin.right;

			LLVMValueRef rhs = emit_expr(cg, (Expr*)bin.right);

			if (bin.op == OP_ASSIGN)
			{
				LLVMValueRef ptr = emit_lvalue(cg, lhs_expr);
				assert(ptr != null);
				LLVMTypeRef store_inst = llvm::build_store(cg.builder, rhs, ptr);
				return rhs;
			}

			LLVMValueRef lhs = emit_expr(cg, (Expr*)bin.left);

			TypeKind type_kind = lhs_expr.resolved_type.canonical.kind;
			bool is_float = (type_kind == TYPE_F32 || type_kind == TYPE_F64);
			bool is_signed = (type_kind == TYPE_I8 || type_kind == TYPE_I16 ||
							  type_kind == TYPE_I32 || type_kind == TYPE_I64);

			switch (bin.op)
			{
				case OP_ADD:
					return is_float
						? llvm::build_f_add(cg.builder, lhs, rhs, "add_tmp")
						: llvm::build_add(cg.builder, lhs, rhs, "add_tmp");
				case OP_SUB:
					return is_float
						? llvm::build_f_sub(cg.builder, lhs, rhs, "sub_tmp")
						: llvm::build_sub(cg.builder, lhs, rhs, "sub_tmp");
				case OP_MULT:
					return is_float
						? llvm::build_f_mul(cg.builder, lhs, rhs, "mul_tmp")
						: llvm::build_mul(cg.builder, lhs, rhs, "mul_tmp");
				case OP_DIV:
					if (is_float) return llvm::build_f_div(cg.builder, lhs, rhs, "div_tmp");
					return is_signed
						? llvm::build_s_div(cg.builder, lhs, rhs, "div_tmp")
						: llvm::build_u_div(cg.builder, lhs, rhs, "div_tmp");

				case OP_EQ:
		            return is_float
		                ? llvm::build_f_cmp(cg.builder, REAL_OEQ, lhs, rhs, "eq_tmp")
		                : llvm::build_i_cmp(cg.builder, INT_EQ, lhs, rhs, "eq_tmp");
		        case OP_NE:
		            return is_float
		                ? llvm::build_f_cmp(cg.builder, REAL_ONE, lhs, rhs, "ne_tmp")
		                : llvm::build_i_cmp(cg.builder, INT_NE, lhs, rhs, "ne_tmp");
		        case OP_GT:
		            return is_float
		                ? llvm::build_f_cmp(cg.builder, REAL_OGT, lhs, rhs, "gt_tmp")
		                : llvm::build_i_cmp(cg.builder, is_signed ? INT_SGT : INT_UGT, lhs, rhs, "gt_tmp");
		        case OP_LT:
		            return is_float
		                ? llvm::build_f_cmp(cg.builder, REAL_OLT, lhs, rhs, "lt_tmp")
		                : llvm::build_i_cmp(cg.builder, is_signed ? INT_SLT : INT_ULT, lhs, rhs, "lt_tmp");
		        case OP_GE:
		            return is_float
		                ? llvm::build_f_cmp(cg.builder, REAL_OGE, lhs, rhs, "ge_tmp")
		                : llvm::build_i_cmp(cg.builder, is_signed ? INT_SGE : INT_UGE, lhs, rhs, "ge_tmp");
		        case OP_LE:
		            return is_float
		                ? llvm::build_f_cmp(cg.builder, REAL_OLE, lhs, rhs, "le_tmp")
		                : llvm::build_i_cmp(cg.builder, is_signed ? INT_SLE : INT_ULE, lhs, rhs, "le_tmp");

				case OP_ADD_ASSIGN:
					LLVMValueRef ptr = emit_lvalue(cg, lhs_expr);
					assert(ptr != null);

					LLVMValueRef new_val = is_float
						? llvm::build_f_add(cg.builder, lhs, rhs, "add_tmp")
						: llvm::build_add(cg.builder, lhs, rhs, "add_tmp");

					LLVMValueRef store_inst = llvm::build_store(cg.builder, new_val, ptr);
					return new_val;
				case OP_SUB_ASSIGN:
				{
					LLVMValueRef ptr = emit_lvalue(cg, lhs_expr);
					assert(ptr != null);

					LLVMValueRef new_val = is_float
						? llvm::build_f_sub(cg.builder, lhs, rhs, "sub_tmp")
						: llvm::build_sub(cg.builder, lhs, rhs, "sub_tmp");

					LLVMValueRef store_inst = llvm::build_store(cg.builder, new_val, ptr);

					return new_val;
				}
				case OP_MULT_ASSIGN:
				{
					LLVMValueRef ptr = emit_lvalue(cg, lhs_expr);
					assert(ptr != null);

					LLVMValueRef new_val = is_float
						? llvm::build_f_mul(cg.builder, lhs, rhs, "mul_tmp")
						: llvm::build_mul(cg.builder, lhs, rhs, "mul_tmp");

					LLVMValueRef store_inst = llvm::build_store(cg.builder, new_val, ptr);

					return new_val;
				}
				case OP_DIV_ASSIGN:
				{
					LLVMValueRef ptr = emit_lvalue(cg, lhs_expr);
					assert(ptr != null);

					LLVMValueRef new_val = null;
					if (is_float)
					{
						new_val = llvm::build_f_div(cg.builder, lhs, rhs, "div_tmp");
					}
					else
					{
						new_val = is_signed
							? llvm::build_s_div(cg.builder, lhs, rhs, "div_tmp")
							: llvm::build_u_div(cg.builder, lhs, rhs, "div_tmp");
					}

					LLVMValueRef store_inst = llvm::build_store(cg.builder, new_val, ptr);

					return new_val;
				}
				default:
					diagnostics::log_error("Unhandled binary operator in codegen: %s", bin.op.description);
					unreachable();
			}
		}
		case IDENT_EXPR:
		{
			IdentExpr* ident_expr = expr.as(IdentExpr);

			if (ident_expr.decl != null && ident_expr.decl.kind == FN_DECL)
			{
    			return get_or_add_function(cg, ident_expr.decl, ident_expr.ident.text);
			}

			LLVMValueRef alloca_ptr = cg.locals.get(ident_expr.decl) ?? null;
			if (alloca_ptr == null)
			{
				diagnostics::error(cg.context, expr.range,
					"Local variable '%s' has no allocated space", ident_expr.ident.text);
				unreachable();
			}

			LLVMTypeRef llvm_type = map_type(cg, ident_expr.decl.resolved_type);
			if (!llvm_type)
			{
				diagnostics::log_error("Failed to map llvm_type, from variable");
				unreachable();
			}
			if (!cg.builder)
			{
				diagnostics::log_error("builder is null");
				unreachable();
			}
			LLVMValueRef load_inst = llvm::build_load_2(cg.builder, llvm_type, alloca_ptr, (CChar*)ident_expr.ident.text.ptr);
			return load_inst;
		}
		case LITERAL_EXPR:
		{
			LiteralExpr* lit = expr.as(LiteralExpr);
			diagnostics::log_debug("Literal: %s", lit.value);
			LLVMTypeRef llvm_type = map_type(cg, lit.resolved_type);

			switch (lit.lit_kind)
			{
				case INT:
					return llvm::const_int(llvm_type, (CULongLong)lit.resolved.integer, 1);
				case FLOAT:
					return llvm::const_real(llvm_type, lit.resolved._float);
				case BOOL:
					return llvm::const_int(llvm_type, (ulong)lit.resolved.boolean, 0);
				case STRING:
					return emit_global_string_const(cg, lit.value);
				default:
					diagnostics::log_error("Unsupported literal kind");
					unreachable();
			}
		}
		case CAST_EXPR:
		{
			CastExpr* cast = expr.as(CastExpr);
			LLVMValueRef operand_val = emit_expr(cg, (Expr*)cast.operand);

			Type* src_type = ((Expr*)cast.operand).resolved_type;
			Type* dst_type = cast.resolved_type;

			return emit_cast(cg, operand_val, src_type, dst_type);
		}
		case POST_UNARY_EXPR:
		{
			PostUnaryExpr* post = expr.as(PostUnaryExpr);
			Expr* operand = (Expr*)post.expr;

			LLVMValueRef ptr = emit_lvalue(cg, operand);
			if (ptr == null) return null;

			Type* type = operand.resolved_type.canonical != null
				? operand.resolved_type.canonical
				: operand.resolved_type;
			LLVMTypeRef llvm_type = map_type(cg, type);

			// Load the original value
			LLVMValueRef old_val = llvm::build_load_2(
				cg.builder,
				llvm_type,
				ptr,
				"post_old"
			);

			LLVMValueRef new_val = null;
			bool is_inc = (post.operator == UNARYOP_INC);

			if (type.is_float())
			{
				LLVMValueRef step = llvm::const_real(llvm_type, 1.0);
				new_val = is_inc
					? llvm::build_f_add(cg.builder, old_val, step, "inc_tmp")
					: llvm::build_f_sub(cg.builder, old_val, step, "dec_tmp");
			}
			else if (type.is_integer())
			{
				LLVMValueRef step = llvm::const_int(llvm_type, 1, 0);
				new_val = is_inc
					? llvm::build_add(cg.builder, old_val, step, "inc_tmp")
					: llvm::build_sub(cg.builder, old_val, step, "dec_tmp");
			}
			else if (type.kind == TYPE_POINTER)
			{
				LLVMTypeRef pointee_llvm = map_type(cg, type.canonical);
				LLVMValueRef step = llvm::const_int(
					llvm::int_32_type_in_context(cg.llvm_ctx),
					is_inc ? 1 : -1,
					1
				);
				new_val = llvm::build_gep2(
					cg.builder,
					pointee_llvm,
					old_val,
					&step,
					1,
					"ptr_idx"
				);
			}

			// Store the new value back into memory
			llvm::build_store(cg.builder, new_val, ptr);

			//  Return old value for postfix evaluation
			return old_val;
		}
		case CALL_EXPR:
        {
            CallExpr* call = expr.as(CallExpr);

            LLVMValueRef callee_val = emit_expr(cg, (Expr*)call.callee);
            if (callee_val == null) return null;

            int arg_count = call.args.len;
            LLVMValueRef* arg_values = alloc::alloc_array(cg.alloc, LLVMValueRef, arg_count);
            for (int i = 0; i < arg_count; i++)
            {
                arg_values[i] = emit_expr(cg, (Expr*)call.args[i]);
                if (arg_values[i] == null) return null;
            }

            Type* callee_type = ((Expr*)call.callee).resolved_type;
            if (callee_type.kind == TYPE_REF || callee_type.kind == TYPE_POINTER)
            {
                callee_type = callee_type.canonical;
            }
            LLVMTypeRef fn_llvm_type = map_type(cg, callee_type);
            assert(fn_llvm_type != null && "Failed to map callee_type to LLVMTypeRef");

            return llvm::build_call_2(cg.builder, fn_llvm_type, callee_val, arg_values, (uint)arg_count, "call_tmp");
        }
        case ACCESS_EXPR:
        {
            AccessExpr* access = expr.as(AccessExpr);

            if (access.access_kind == STATIC)
            {
	            if (access.right.kind == CALL_EXPR)
	            {
	                CallExpr* call = access.right.as(CallExpr);
	                if (call.callee.kind != IDENT_EXPR) return null;

	                IdentExpr* callee_ident = call.callee.as(IdentExpr);
	                LLVMValueRef fn_val = get_or_add_function(cg, callee_ident.decl, callee_ident.ident.text);

	                int arg_count = call.args.len;
	                LLVMValueRef* arg_values = alloc::alloc_array(cg.alloc, LLVMValueRef, arg_count);
	                for (int i = 0; i < arg_count; i++)
	                {
	                    arg_values[i] = emit_expr(cg, (Expr*)call.args[i]);
	                }

	                LLVMTypeRef fn_llvm_type = map_type(cg, callee_ident.decl.resolved_type);
	                return llvm::build_call_2(cg.builder, fn_llvm_type, fn_val, arg_values, (uint)arg_count, "call_tmp");
	            }

				if (access.right.kind == IDENT_EXPR)
				{
				    IdentExpr* ident = access.right.as(IdentExpr);
				    if (ident.decl != null && ident.decl.kind == FN_DECL)
				    {
				        return get_or_add_function(cg, ident.decl, ident.ident.text);
				    }

				    String prop_name = ident.ident.text;
				    return llvm::get_named_global(cg.mod, (CChar*)prop_name.ptr);
				}
            }

            Expr* left_expr = (Expr*)access.left;
            LLVMValueRef instance_ptr = emit_lvalue(cg, left_expr);
            if (instance_ptr == null) return null;

            Type* left_t = left_expr.resolved_type;
            while (left_t.kind == TYPE_POINTER || left_t.kind == TYPE_REF)
            {
                left_t = left_t.canonical;
            }

            assert(left_t.data.decl.kind == STRUCT_DECL);

            StructDecl* strukt = left_t.data.decl.as(StructDecl);

            String field_name = access.right.as(IdentExpr).ident.text;
            int field_index = -1;
            for (int i = 0; i < strukt.fields.len; i++)
            {
            	VarDecl* field = strukt.fields[i].as(VarDecl);
                if (field.name.text == field_name)
                {
                    field_index = i;
                    break;
                }
            }

            if (field_index == -1)
            {
                diagnostics::error(cg.context, expr.range, "Struct has no field named '%s'", field_name);
                return null;
            }

            LLVMTypeRef struct_llvm_type = map_type(cg, left_t);

            LLVMValueRef field_ptr = llvm::build_struct_gep2(
                cg.builder,
                struct_llvm_type,
                instance_ptr,
                (CUInt)field_index,
                "field_ptr"
            );

            LLVMTypeRef field_llvm_type = map_type(cg, expr.resolved_type);
            return llvm::build_load_2(cg.builder, field_llvm_type, field_ptr, "field_load");
        }
        default:
			diagnostics::warn(cg.context, expr.range, "Unhandled expr: %s", expr.kind.description);
			return null;
	}
}


fn LLVMValueRef emit_cast(CodegenContext* cg, LLVMValueRef val, Type* src, Type* dst)
{
	if (val == null || src == null || dst == null) return val;

	src = src.canonical != null ? src.canonical : src;
	dst = dst.canonical != null ? dst.canonical : dst;

	if (src == dst) return val;

	LLVMTypeRef target_llvm = dst.llvm_type != null ? dst.llvm_type : map_type(cg, dst);

	// Integer -> Integer
	if (src.is_integer() && dst.is_integer())
	{
		uint src_bits = src.size * 8;
		uint dst_bits = dst.size * 8;

		// Truncate (e.g. i64 -> i32)
		if (src_bits > dst_bits)
		{
			return llvm::build_trunc(cg.builder, val, target_llvm, "cast_trunc");
		}
		// Extend (e.g. i16 -> i32)
		else if (src_bits < dst_bits)
		{
			if (src.is_signed_int())
			{
				return llvm::build_s_ext(cg.builder, val, target_llvm, "cast_sext");
			}
			return llvm::build_z_ext(cg.builder, val, target_llvm, "cast_zext");
		}
		return val;
	}

	// Float -> Float
	if (src.is_float() && dst.is_float())
	{
		if (src.size > dst.size)
		{
			return llvm::build_fp_trunc(cg.builder, val, target_llvm, "cast_fptrunc");
		}
		else if (src.size < dst.size)
		{
			return llvm::build_fp_ext(cg.builder, val, target_llvm, "cast_fpext");
		}
		return val;
	}

	// Integer -> Float
	if (src.is_integer() && dst.is_float())
	{
		if (src.is_signed_int())
		{
			return llvm::build_si_to_fp(cg.builder, val, target_llvm, "cast_sitofp");
		}
		return llvm::build_ui_to_fp(cg.builder, val, target_llvm, "cast_uitofp");
	}

	// Float -> Integer
	if (src.is_integer() && dst.is_float())
	{
		if (dst.is_signed_int())
		{
			return llvm::build_si_to_fp(cg.builder, val, target_llvm, "cast_fptosi");
		}
		return llvm::build_ui_to_fp(cg.builder, val, target_llvm, "cast_fptoui");
	}

	if (src.is_float() && dst.is_integer())
	{
		if (dst.is_signed_int())
		{
			return llvm::build_fp_to_si(cg.builder, val, target_llvm, "cast_fptosi");
		}
		return llvm::build_fp_to_ui(cg.builder, val, target_llvm, "cast_fptoui");
	}

	// Pointer -> Pointer
	if (src.kind == TYPE_POINTER && dst.kind == TYPE_POINTER)
	{
		return llvm::build_pointer_cast(cg.builder, val, target_llvm, "cast_ptrcast");
	}

	// Pointer -> Int
	if (src.kind == TYPE_POINTER && dst.is_integer())
	{
		return llvm::build_ptr_to_int(cg.builder, val, target_llvm, "cast_ptr2int");
	}

	// Int -> Pointer
	if (src.is_integer() && dst.kind == TYPE_POINTER)
	{
		return llvm::build_int_to_ptr(cg.builder, val, target_llvm, "cast_int2ptr");
	}

	// Fallback: Bitcast (reinterpret bits without changing layout)
	return llvm::build_bit_cast(cg.builder, val, target_llvm, "cast_bitcast");
}

fn LLVMValueRef emit_lvalue(CodegenContext* cg, Expr* expr)
{
	switch (expr.kind)
	{
		case IDENT_EXPR:
		{
			IdentExpr* ident = expr.as(IdentExpr);
			if (ident.decl == null) return null;
			return cg.locals.get(ident.decl) ?? null;
		}
		default:
			diagnostics::error(cg.context, expr.range, "Invalid l-value for postfix operation");
			return null;
	}
}
