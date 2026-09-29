module slate::codegen;

import slate::core;
import std::collections;

import llvm;

fn void emit_statement(CodegenContext* cg, Stmt* stmt)
{
	switch (stmt.kind)
	{
		case COMPOUND_STMT:
		{
			CompoundStmt* comp = stmt.as(CompoundStmt);
			foreach (Node* node : comp.statements)
			{
				emit_statement(cg, (Stmt*)node);
			}
			break;
		}
		case RETURN_STMT:
		{
			ReturnStmt* ret = stmt.as(ReturnStmt);

		    if (ret.expr != null)
		    {
		        LLVMValueRef value = emit_expr(cg, (Expr*)ret.expr);
		        llvm::build_ret(cg.builder, value);
		    }
		    else
		    {
		        llvm::build_ret_void(cg.builder);
		    }
		    break;
		}
		case VAR_DECL:
		{
			VarDecl* decl = stmt.as(VarDecl);
		    Type* var_type = decl.resolved_type;

		    if (var_type == null)
            {
                diagnostics::error(cg.context, decl.range, "Missing type for local variable");
                break;
            }

            if (var_type.llvm_type == null)
            {
                var_type.llvm_type = map_type(cg, var_type);
                if (var_type.llvm_type == null)
                {
                    diagnostics::error(cg.context, decl.range, "Failed to map LLVM type for local variable");
                    break;
                }
            }

		    LLVMTypeRef llvm_type = var_type.llvm_type;

		    LLVMValueRef alloca_ptr = llvm::build_alloca(cg.builder, llvm_type, (CChar*)decl.name.text.ptr);
			cg.locals.set(decl, alloca_ptr);

		    if (decl.init_expr != null)
		    {
		        LLVMValueRef init_val = emit_expr(cg, (Expr*)decl.init_expr);

		        if (init_val != null)
		        {
		            llvm::build_store(cg.builder, init_val, alloca_ptr);
		        }
		    }

		    break;
		}
		case EXPR_STMT:
		{
			ExprStmt* expr_stmt = stmt.as(ExprStmt);
			if (!expr_stmt.expr_stmt) return;
			emit_expr(cg, (Expr*)expr_stmt.expr_stmt);
			break;
		}
		case IF_STMT:
		{
			IfStmt* if_stmt = stmt.as(IfStmt);

            // 1. Emit condition expression
            LLVMValueRef cond_val = emit_expr(cg, (Expr*)if_stmt.condition);
            if (cond_val == null) break;

            // 2. Obtain current parent function for block attachment
            LLVMBasicBlockRef current_bb = llvm::get_insert_block(cg.builder);
            LLVMValueRef current_fn = llvm::get_basic_block_parent(current_bb);

            // 3. Create basic blocks
            LLVMBasicBlockRef then_bb = llvm::append_basic_block(current_fn, "if.then");
            LLVMBasicBlockRef merge_bb = llvm::append_basic_block(current_fn, "if.end");
            LLVMBasicBlockRef else_bb = if_stmt.else_body != null
                ? llvm::append_basic_block(current_fn, "if.else")
                : merge_bb;

            // 4. Branch based on condition
            llvm::build_cond_br(cg.builder, cond_val, then_bb, else_bb);

            // 5. Emit 'then' block statements
            llvm::position_builder_at_end(cg.builder, then_bb);
            emit_statement(cg, (Stmt*)if_stmt.then_body);

            // Only add jump to merge block if 'then' block doesn't already terminate (e.g. return)
            if (llvm::get_basic_block_terminator(llvm::get_insert_block(cg.builder)) == null)
            {
                llvm::build_br(cg.builder, merge_bb);
            }

            // 6. Emit 'else' block statements if present
            if (if_stmt.else_body != null)
            {
                llvm::position_builder_at_end(cg.builder, else_bb);
                emit_statement(cg, (Stmt*)if_stmt.else_body);

                if (llvm::get_basic_block_terminator(llvm::get_insert_block(cg.builder)) == null)
                {
                    llvm::build_br(cg.builder, merge_bb);
                }
            }

            // 7. Move builder to merge block for subsequent statements
            llvm::position_builder_at_end(cg.builder, merge_bb);
            break;
		}
		default:
			diagnostics::warn(cg.context, stmt.range, "Unhandled statement");
	}
}
