module slate::core::visitor;

import slate::core::ast;

enum ChildVisitResult : int
{
	BREAK,    // Terminate the entire walk
	CONTINUE, // Continue to the next sibling
	RECURSE   // Dive into the children of the current node
}

struct VisitorHooks
{
	CursorVisitor on_enter;
	CursorVisitor on_exit; // Called after children are processed
}

alias CursorVisitor = fn ChildVisitResult(Node* cursor, Node* parent, void* user_data);

<*
 @require hooks.on_enter != null
*>
fn bool visit(Node* child, Node* parent, VisitorHooks hooks, void* data)
{
	ChildVisitResult res = hooks.on_enter(child, parent, data);
	if (res == ChildVisitResult.BREAK) return false; // Stop the whole walk

	if (res == ChildVisitResult.RECURSE)
	{
		// Recursively visit the children of this child
		if (!visit_children(child, hooks, data)) return false;
	}

	if (hooks.on_exit)
	{
		hooks.on_exit(child, parent, data);
	}

	return true; // Continue to next sibling
}

<*
 Visit children
 returns false if a break was requested
 @param parent : "The Cursor to visit children on"
 @param hooks : "callback functions that will be invoked for all children of 'parent'"
 @param data : "user data to be passed around"
*>
fn bool visit_children(Node* parent, VisitorHooks hooks, void* data)
{
	if (!parent.is_valid()) return true;
	Node* node = parent;

	switch
	{
		case node.kind.is_decl():
			if (!visit_decls(node, parent, hooks, data)) return false;
			break;
		case node.kind.is_stmt():
			if (!visit_stmts(node, parent, hooks, data)) return false;
			break;
		case node.kind.is_expr():
			if (!visit_exprs(node, parent, hooks, data)) return false;
			break;
		default:
			unreachable("Unknown Node type");
	}

	return true;
}

fn bool visit_decls(Node* node, Node* parent, VisitorHooks hooks, void* data) @private
{
	switch (node.kind)
	{
		case MODULE_DECL:
		{
			ModuleDecl* md = node.as(ModuleDecl);
			if (md.path && !visit(md.path, parent, hooks, data)) return false;
			break;
		}
		case IMPORT_DECL:
		{
			ImportDecl* id = node.as(ImportDecl);
			foreach (path : id.paths)
			{
				if (!visit(path, parent, hooks, data)) return false;
			}
			break;
		}
		case FN_DECL:
		{
			FnDecl* fndecl = node.as(FnDecl);
			if (fndecl.ret_type && !visit(fndecl.ret_type, parent, hooks, data)) return false;
			foreach (param : fndecl.params)
			{
				if (!visit(param, parent, hooks, data)) return false;
			}
			if (fndecl.body && !visit(fndecl.body, parent, hooks, data)) return false;
			break;
		}
		case STRUCT_DECL:
		{
			StructDecl* structdecl = node.as(StructDecl);
			foreach (field : structdecl.fields)
			{
				if (!visit(field, parent, hooks, data)) return false;
			}
			if (structdecl.next)
			{
				if (!visit(structdecl.next, parent, hooks, data)) return false;
			}
			if (structdecl.type)
			{
				if (!visit(structdecl.type, parent, hooks, data)) return false;
			}
			break;
		}
		case ENUM_DECL:
		{
			EnumDecl* ed = node.as(EnumDecl);
			if (ed.backing_type)
			{
				if (!visit(ed.backing_type, parent, hooks, data)) return false;
			}
			foreach (vari : ed.variants)
			{
				if (!visit(vari, parent, hooks, data)) return false;
			}
			foreach (param : ed.assoc_params)
			{
				if (!visit(param, parent, hooks, data)) return false;
			}
			break;
		}
		case VAR_DECL:
		{
			VarDecl* vardecl = node.as(VarDecl);
			if (vardecl.type && !visit(vardecl.type, parent, hooks, data)) return false;
			if (vardecl.init_expr && !visit(vardecl.init_expr, parent, hooks, data)) return false;
			if (vardecl.next && !visit(vardecl.next, parent, hooks, data)) return false;

			break;
		}
		default:
			break;
	}

	return true;
}

fn bool visit_stmts(Node* node, Node* parent, VisitorHooks hooks, void* data) @private
{
	switch (node.kind)
	{
		case COMPOUND_STMT:
		{
			CompoundStmt* comp = node.as(CompoundStmt);
			foreach (stmt : comp.statements)
			{
				if (!visit(stmt, parent, hooks, data)) return false;
			}
			break;
		}
		default:
			break;
	}

	return true;
}

fn bool visit_exprs(Node* node, Node* parent, VisitorHooks hooks, void* data) @private
{
	switch(node.kind)
	{
		case ACCESS_EXPR:
		{
			AccessExpr* access = node.as(AccessExpr);
			if (access.left && !visit(access.left, parent, hooks, data)) return false;
			if (access.right && !visit(access.right, parent, hooks, data)) return false;
			break;
		}

		case BINARY_EXPR:
		{
			BinaryExpr* bin = node.as(BinaryExpr);
			if (bin.left && !visit(bin.left, parent, hooks, data)) return false;
			if (bin.right && !visit(bin.right, parent, hooks, data)) return false;
			break;
		}
		case TYPE_EXPR:
		{
			TypeExpr* te = node.as(TypeExpr);
			switch (te.type_kind)
			{
				case TYPE_IDENTIFIER:
				{
					// Optional module path node (e.g., the 'foo::' in 'foo::MyStruct')
					if (te.unresolved.path && !visit(te.unresolved.path, parent, hooks, data)) return false;
					break;
				}
				case TYPE_POINTER:
				case TYPE_SLICE:
				{
					if (te.modify.base && !visit(te.modify.base, parent, hooks, data)) return false;
					break;
				}
				case TYPE_ARRAY:
				case TYPE_VECTOR:
				{
					if (te.array.base && !visit(te.array.base, parent, hooks, data)) return false;
					if (te.array.len_expr && !visit(te.array.len_expr, parent, hooks, data)) return false;
					break;
				}
				case TYPE_GENERIC:
				{
					if (te.generic.base && !visit(te.generic.base, parent, hooks, data)) return false;
					foreach (param : te.generic.params)
					{
						if (!visit(param, parent, hooks, data)) return false;
					}
					break;
				}
				default:
					unreachable();
			}
			break;
		}
		default:
			break;
	}

	return true;
}
