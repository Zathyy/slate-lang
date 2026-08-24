module slate::core::ast;

import std::collections::list;

enum NodeKind : char
{
	ERROR,
	PATH_ATOM,

	MODULE_DECL,
	IMPORT_DECL,
	STRUCT_DECL,
	ENUM_DECL,
	VAR_DECL,
	TYPEDEF_DECL,
	FN_DECL,
	ATTRIBUTE_DECL,
	ERROR_DECL,
	ERROR_UNION_DECL,

	COMPOUND_STMT,
	IF_STMT,
	SWITCH_STMT,
	CASE_STMT,
	CONTINUE_BREAK_STMT,
	DEFAULT_STMT,
	RETURN_STMT,
	FOR_STMT,
	WHILE_STMT,
	EXPR_STMT,
	NOP_STMT,
	DEFER_STMT,
	ASSERT_STMT,

	CALL_EXPR,
	BINARY_EXPR,
	BUILTIN_EXPR,
	UNARY_EXPR,
	IDENT_EXPR,
	TYPE_EXPR,
	EXPR_LIST,
	LITERAL_EXPR,
	COND_EXPR,
	TERNARY_EXPR,
	CAST_EXPR,
	GROUP_EXPR,
	//GENERIC_EXPR,
	DESIGNATOR_EXPR,
	DESIGNATED_INITIALIZER_EXPR,
	INITIALIZER_LIST_EXPR,
	ACCESS_EXPR,
	RANGE_EXPR,
}

fn bool NodeKind.is_decl(self) @inline
{
	return self.ordinal >= NodeKind.MODULE_DECL.ordinal && self.ordinal <= NodeKind.FN_DECL.ordinal;
}

fn bool NodeKind.is_stmt(self) @inline
{
	return self.ordinal >= NodeKind.COMPOUND_STMT.ordinal && self.ordinal <= NodeKind.ASSERT_STMT.ordinal;
}

fn bool NodeKind.is_expr(self) @inline
{
	return self.ordinal >= NodeKind.CALL_EXPR.ordinal && self.ordinal <= NodeKind.RANGE_EXPR.ordinal;
}
