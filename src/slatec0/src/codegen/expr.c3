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
			Expr* rhs_expr = (Expr*)bin.left;
            LLVMValueRef lhs = emit_expr(cg, (Expr*)bin.left);
            LLVMValueRef rhs = emit_expr(cg, (Expr*)bin.right);

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
                default:
                    diagnostics::log_error("Unhandled binary operator in codegen");
                    return null;
            }
		}
		case IDENT_EXPR:
		case LITERAL_EXPR:
		{
			LiteralExpr* lit = expr.as(LiteralExpr);
            LLVMTypeRef llvm_type = map_type(cg, expr.resolved_type);

            switch (lit.lit_kind)
            {
                case INT:
                    return llvm::const_int(llvm_type, (CULongLong)lit.resolved.integer, 1);
                case FLOAT:
                    return llvm::const_real(llvm_type, lit.resolved._float);
                case BOOL:
                    return llvm::const_int(llvm_type, (ulong)lit.resolved.boolean, 0);
                default:
                    diagnostics::log_error("Unsupported literal kind");
                    return null;
            }
		}
		default:
			diagnostics::warn(cg.context, expr.range, "Unhandled expr");
			return null;
	}
}
