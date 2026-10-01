module slate::emitter;

import slate::core::ast;
import slate::sema;
import slate::core::diagnostics;

import std::io;
import std::collections;

SemaContext* ctx = null;
Module* mod = null;
Scope* scope = null;

fn void begin(SemaContext* _ctx, Module* _mod)
{
	ctx = _ctx;
	mod = _mod;
	scope = _mod.scope;
}

fn void forward_declare(Node* node, File* file)
{
	switch (node.kind)
	{
		case STRUCT_DECL:
		{
			StructDecl* decl = node.as(StructDecl);
			file.write(string::tformat("typedef struct %s %s;\n", decl.node.name.text, decl.node.name.text))!!;
		}
		case FN_DECL:
		{
			FnDecl* func = node.as(FnDecl);
			String func_name = func.node.name.text;
			scope = ctx.node_scopes.get((Node*)func) ?? scope;

			// Skip main or let main match its standard signature
			if (func_name == "main")
			{
				file.write("int main(int argc, char** argv);\n")!!;
			}
			else
			{
				String ret_str = func.ret_type ? (ast::raw_type_identifier(func.ret_type) ?? "void") : "void";
				file.write(string::tformat("%s %s__%s(", ret_str, mod.name.treplace("::", "__"), func_name))!!;

				bool first = true;
				foreach (Node* param_node : func.params)
				{
					VarDecl* param = param_node.as(VarDecl);
					if (!first) file.write(", ")!!;
					String p_type = ast::type_to_c_string(param.type);

					if (param.var_flags.is_self_by_ref)
					{
						p_type = string::tformat("%s*", ast::type_to_c_string(func.method_type));
					}
					else if (param.var_flags.is_self)
					{
						p_type = ast::type_to_c_string(func.method_type);
					}

					if (param.var_flags.is_variadic)
					{
						file.write("...")!!;
						continue;
					}

					file.write(string::tformat("%s %s", p_type, param.node.name.text))!!;
					first = false;
				}
				file.write(");\n")!!;
			}
			break;
		}
		default:
	}
}

fn void emit_node_to_c(Node* node, File* file) => @pool()
{
	switch (node.kind)
	{
		case STRUCT_DECL:
		{
			StructDecl* s = node.as(StructDecl);
			scope = ctx.node_scopes.get((Node*)s) ?? scope;
			file.write(string::tformat("typedef struct %s {\n", s.node.name.text))!!;
			foreach (Node* field_node : s.fields)
			{
				VarDecl* field = field_node.as(VarDecl);
				String type_str = ast::type_to_c_string(field.type);
				file.write(string::tformat("    %s %s;\n", type_str, field.node.name.text))!!;
			}
			file.write(string::tformat("} %s;\n\n", s.node.name.text))!!;
			break;
		}
		case FN_DECL:
		{
			FnDecl* func = node.as(FnDecl);
			String func_name = func.node.name.text;
			scope = ctx.node_scopes.get((Node*)func) ?? scope;

			if (func_name == "main")
			{
				file.write("int main(int argc, char** argv)\n")!!;
			}
			else
			{
				String ret_str = func.ret_type ? (ast::raw_type_identifier(func.ret_type) ?? "void") : "void";
				String func_sig_name = (func_name == "main") ? "main" : string::tformat("%s__%s", mod.name.treplace("::", "__"), func_name);
				file.write(string::tformat("%s %s(", ret_str, func_sig_name))!!;

				bool first = true;
				foreach (Node* param_node : func.params)
				{
					VarDecl* param = param_node.as(VarDecl);
					if (!first) file.write(", ")!!;
					String p_type = ast::type_to_c_string(param.type);

					if (param.var_flags.is_self_by_ref)
					{
						p_type = string::tformat("%s*", ast::type_to_c_string(func.method_type));
					}
					else if (param.var_flags.is_self)
					{
						p_type = ast::type_to_c_string(func.method_type);
					}

					if (param.var_flags.is_variadic)
					{
						file.write("...")!!;
						continue;
					}

					file.write(string::tformat("%s %s", p_type, param.node.name.text))!!;
					first = false;
				}
				file.write(")\n")!!;
			}

			if (func.body)
			{
				file.write(node_to_string(func.body))!!;
			}
			else
			{
				file.write(";\n")!!;
			}
			file.write("\n")!!;
			break;
		}
		case TYPEDEF_DECL:
		{
			TypedefDecl* td = node.as(TypedefDecl);
			scope = ctx.node_scopes.get((Node*)td) ?? scope;
			file.write(string::tformat("typedef %s %s;", ast::type_to_c_string(td.base_type), td.node.name.text))!!;
			file.write("\n")!!;
			break;
		}
		default:
			break;
	}
}

fn String node_to_string(Node* node)
{
	if (!node) return "";

	switch (node.kind)
	{
		case COMPOUND_STMT:
		{
			CompoundStmt* block = node.as(CompoundStmt);
			String sb = "{";
			foreach (Node* stmt : block.statements)
			{
				sb = string::tformat("%s\n    %s", sb, node_to_string(stmt));
			}
			sb = string::tformat("%s\n}", sb);
			return sb;
		}
		case RETURN_STMT:
		{
			ReturnStmt* ret = node.as(ReturnStmt);
			if (ret.expr)
			{
				return string::tformat("return %s;", node_to_string(ret.expr));
			}
			return "return;";
		}
		case EXPR_STMT:
		{
			ExprStmt* es = node.as(ExprStmt);
			return string::tformat("%s;", node_to_string(es.expr_stmt));
		}
		case BINARY_EXPR:
		{
			BinaryExpr* bin = node.as(BinaryExpr);
			String op_str = get_binop_string(bin.op);
			return string::tformat("(%s %s %s)", node_to_string(bin.left), op_str, node_to_string(bin.right));
		}
		case LITERAL_EXPR:
		{
			LiteralExpr* lit = node.as(LiteralExpr);
			return lit.value;
		}
		case IDENT_EXPR:
		{
			IdentExpr* ident = node.as(IdentExpr);
			return ident.ident.text;
		}
		case GROUP_EXPR:
		{
			GroupExpr* group = node.as(GroupExpr);
			return string::tformat("(%s)", node_to_string(group.inner));
		}
		case CALL_EXPR:
		{
			CallExpr* call = node.as(CallExpr);
			String sb = string::tformat("%s(", node_to_string(call.callee));
			bool first_arg = true;
			foreach (Node* arg : call.args)
			{
				if (!first_arg) sb = string::tformat("%s, ", sb);
				sb = string::tformat("%s%s", sb, node_to_string(arg));
				first_arg = false;
			}
			sb = string::tformat("%s)", sb);
			return sb;
		}
		case ACCESS_EXPR:
		{
			AccessExpr* acc = node.as(AccessExpr);

			if (acc.access_kind == STATIC)
			{
				String left_str = node_to_string(acc.left);
                String right_str = node_to_string(acc.right);
                if (left_str == "libc")
                {
                    return right_str;
                }

                Decl* decl = scope::lookup(ctx, scope, right_str);
                if (!decl)
                {
                	diagnostics::error(ctx.context, acc.right.range, "Unknown symbol");
                 	return "<invalid>";
                }

                return decl.qname.treplace("::", "__");
			}
			else
			{
				return string::tformat("%s.%s", node_to_string(acc.left), node_to_string(acc.right));
			}
		}
		case VAR_DECL:
		{
			VarDecl* v = node.as(VarDecl);
			String type_str = ast::raw_type_identifier(v.type) ?? "int";
			if (v.init_expr)
			{
				return string::tformat("%s %s = (%s)%s;", type_str, v.node.name.text, type_str, node_to_string(v.init_expr));
			}
			return string::tformat("%s %s;", type_str, v.node.name.text);
		}
		default:
			return string::tformat("// [unsupported node ( %s )]", node.kind.description);
	}
}

fn String get_binop_string(OperatorKind op)
{
	switch (op)
	{
		case OP_ADD: return "+";
		case OP_SUB: return "-";
		case OP_MULT: return "*";
		case OP_DIV: return "/";
		case OP_EQ:  return "==";
		case OP_NE:  return "!=";
		case OP_LT:  return "<";
		case OP_LE:  return "<=";
		case OP_GT:  return ">";
		case OP_GE:  return ">=";
		case OP_AND: return "&&";
		case OP_OR:  return "||";
		case OP_ASSIGN: return "=";
		case OP_MULT_ASSIGN: return "*=";
		case OP_ADD_ASSIGN: return "+=";
		case OP_SUB_ASSIGN: return "-=";
		default: return "+";
	}
}
