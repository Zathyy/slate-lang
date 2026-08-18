module slate::core::ast;

import slate::lexer;

import std::collections::list;

<*
 - `generics`: generic_decl | null
*>
struct ModuleDecl
{
	inline Node node;
	Node* path;
}

struct ImportDecl
{
	inline Node node;
	NodeArray paths;
}

struct AttributeDecl
{
	inline Node node;
	Node* expr;
	Ident* name;
	AttributeKind attr_kind;
}

struct ErrorDecl
{
	inline Node node;
	Ident* name;
	NodeArray fields;
}

struct ErrorUnionDecl
{
	inline Node node;
	Node* err;
	Node* type;
}

<*
 Fields:
- name: The interned typedef type name.
- base_type: The underlying TYPE_EXPR this distinct type is based on.
- generics: Optional generic declaration parameters, e.g. Type in `typedef Option<Type> = Type*`.
- interfaces: Optional interface type list after the typedef name.
- attributes: Attributes written on the typedef declaration or base type.
- is_inline: True when the declaration uses '= inline type'.
*>
struct TypedefDecl
{
	inline Node node;
	Ident* name;
	Node* base_type;
	Node* generics;
	bool is_inline;
}

struct FnDecl
{
	inline Node node;
	Ident* name;
	Node* ret_type;
	Node* body;
	NodeArray generics;
	NodeArray params;
}

<*
 VarDecl: represents (Global, Local, Field) variables
- type: type_expr if has type
- init_expr: if has initializer
- next: Var_decl if chained (e.g. int a, b, c; )
*>
struct VarDecl
{
	inline Node node;
	VarDeclKind var_kind;
	Ident* name;
	Node* type;
	Node* init_expr;
	Node* next;
}

struct EnumDecl
{
	inline Node node;
	Ident* name;
	bool is_inline_backing;
	Node* backing_type; // optional: ":" type
	NodeArray assoc_params; // optional enum_param_list inside ":"
	NodeArray variants;
}

<*
 StructDecl is both for structs & unions `is_union`
 - `generics`: generic_decl | null
*>
struct StructDecl
{
	inline Node node;
	NodeArray fields;
	Node* type;
	Node* next;
	Ident* name;
}
