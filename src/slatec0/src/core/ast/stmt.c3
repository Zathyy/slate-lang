module slate::core::ast;

import std::collections::list;

struct IfStmt
{
	inline Node node;
	Node* condition;
	Node* then_body;
	Node* else_body;
}

struct CompoundStmt
{
	inline Node node;
	NodeArray statements;
}

struct SwitchStmt
{
	inline Node node;
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
	inline Node node;
	Node* expr;
	Node* to_expr;
	Node* body;
}

<*
 -body: compound_stmt
*>
struct DefaultStmt
{
	inline Node node;
	Node* body;
}

struct ContinueBreakStmt
{
	inline Node node;
	bool is_continue;
}

struct ReturnStmt
{
	inline Node node;
	Node* expr;
}

struct ExprStmt
{
	inline Node node;
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
	inline Node node;
	Node* init;
	Node* cond;
	Node* incr;
	Node* body;
}

struct WhileStmt
{
	inline Node node;
	Node* cond;
	Node* body;
}

struct DoWhileStmt
{
	inline Node node;
	Node* body;
	Node* cond;
}

struct DeferStmt
{
	inline Node node;
	DeferKind defer_kind;
	Node* ident;
	Node* body;
}

struct AssertStmt
{
	inline Node node;
	Node* expr;
	Node* message;
	NodeArray args;
}

struct NopStmt
{
	inline Node node;
}
