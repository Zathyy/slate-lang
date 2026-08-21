module slate::core::ast;

import std::collections::list;

struct IfStmt
{
	inline Stmt node;
	Node* condition;
	Node* then_body;
	Node* else_body;
}

struct CompoundStmt
{
	inline Stmt node;
	NodeArray statements;
}

struct SwitchStmt
{
	inline Stmt node;
	NodeArray cases;
	Node* cond;
}

<*
 - expr:
 - to_expr:
 - body: compound_stmt
*>
struct CaseStmt
{
	inline Stmt node;
	Node* expr;
	Node* to_expr;
	Node* body;
}

<*
 -body: compound_stmt
*>
struct DefaultStmt
{
	inline Stmt node;
	Node* body;
}

struct ContinueBreakStmt
{
	inline Stmt node;
	bool is_continue;
}

struct ReturnStmt
{
	inline Stmt node;
	Node* expr;
}

struct ExprStmt
{
	inline Stmt node;
	Node* expr_stmt;
}

<*
 - init: expr_list?
 - cond: cond_expr?
 - incr: cond_ist?
 - body: stmt
*>
struct ForStmt
{
	inline Stmt node;
	Node* init;
	Node* cond;
	Node* incr;
	Node* body;
}

struct WhileStmt
{
	inline Stmt node;
	Node* cond;
	Node* body;
}

struct DoWhileStmt
{
	inline Stmt node;
	Node* body;
	Node* cond;
}

struct DeferStmt
{
	inline Stmt node;
	DeferKind defer_kind;
	Node* ident;
	Node* body;
}

struct AssertStmt
{
	inline Stmt node;
	Node* expr;
	Node* message;
	NodeArray args;
}

struct NopStmt
{
	inline Stmt node;
}
