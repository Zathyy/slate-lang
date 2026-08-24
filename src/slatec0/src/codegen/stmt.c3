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
		default:
			diagnostics::warn(cg.context, stmt.range, "Unhandled statement");
	}
}
