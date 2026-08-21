module slate::core::ast;

import slate::lexer;

import std::collections::list;

struct TryExpr
{
    inline Expr node;
    Node* operand; // Expression evaluating to an ErrorUnion
}

// Represents 'expr catch |err| { ... }'
struct CatchExpr
{
    inline Expr node;
    Node* operand;        // Expression evaluating to an ErrorUnion
    String err_var_name;  // Binding name for error payload (e.g., "err")
    Node* body;           // Block or expression executed on error
}

<*
 Payloads:
- unresolved: TYPE_IDENTIFIER name and optional module path.
- modify: TYPE_POINTER and TYPE_SLICE base type.
- array: TYPE_ARRAY and TYPE_VECTOR base type plus length expression.
  `len_expr` is null for inferred arrays such as `Type[*]`.
- generic: TYPE_GENERIC base type and generic argument expressions.
- func: TYPE_FUNCTION return type and VAR_DECL parameter nodes.
*>
struct TypeExpr
{
	inline Expr node;
	TypeExprKind type_kind;
	bool is_const;

	union
	{
		struct unresolved
		{
			Ident* name;
			Node* path;
		}

		struct modify
		{
			Node* base;
		}

		struct array
		{
			Node* base;
			Node* len_expr;
		}

		struct generic
		{
			Node* base;
			Node*[] params;
		}
	}
}

struct BinaryExpr
{
	inline Expr node;
	Node* left;
	Node* right;
	OperatorKind op;
}

struct IdentExpr
{
	inline Expr node;
	Ident* ident;
	Node* path_expr;
}

struct CallExpr
{
	inline Expr node;
	bool is_outer_call;
	Node* callee;
	NodeArray args;
}

struct ExprList
{
	inline Expr node;
	NodeArray exprs;
}

enum LiteralKind
{
    INT,      // "42", "0x1F", "0b1010"
    FLOAT,    // "3.14", "1e-10"
    STRING,   // "\"hello\n\""
    CHAR,     // "'a'", "'\n'"
    BOOL,     // "true", "false"
    NULL,     // "null"
}

struct LiteralExpr
{
	inline Expr node;
	LiteralKind lit_kind;
	String value;
}

struct UnaryExpr
{
	inline Expr node;
	UnaryOpKind operator;
	Node* expr;
}

struct CondExpr
{
	inline Expr node;
	NodeArray exprs;
}

struct BuiltinExpr
{
	inline Expr node;
	Ident* value;
}

<*

*>
struct TernaryExpr
{
	inline Expr node;
	Node* cond;
	Node* then_expr;
	Node* else_expr;
	bool is_grouped;
	bool is_const;
}

struct NamedArgExpr
{
	inline Expr node;
	Ident* name;
	Node* value;
}

struct CastExpr
{
	inline Expr node;
	Node* operand;
	Node* inner;
}

struct GroupExpr
{
	inline Expr node;
	Node* inner;
}

struct InitializerListExpr
{
	inline Expr node;
	NodeArray exprs;
}

<*
 - `path`:  Left-hand side part of the path (null if it's the start)
 - `field`: Valid if kind == PERIOD (.field)
 - `start`: Valid if kind == INDEX or RANGE ([start])
 - `end`:   Valid if kind is RANGE ([start .. end])
*>
struct DesignatorExpr
{
	inline Expr node;
	DesignatorKind designator_kind;
	Node* path;

	union data
	{
		Node* field;
		Node* range;
	}
}

<*
 - `path`: DESIGNATOR_EXPR node chain (.foo.bar)
 - `value`: assigned expression node (= 42)
*>
struct DesignatedInitializerExpr
{
	inline Expr node;
	Node* path;
	Node* value;
}

struct AccessExpr
{
	inline Expr node;
	AccessKind access_kind;
	Node* left;
	Node* right;
}

<*
 - `start_from_end`: True if start had '^' (BIT_XOR)
 - `end_from_end`: True if end had '^' (BIT_XOR)
*>
struct RangeExpr
{
	inline Expr node;
	RangeKind range_kind;
	bool start_from_end;
	bool end_from_end;
	Node* start;
	Node* end;
}
