module slate::core::ast;

import slate::lexer;

import std::collections::list;

<*
 - `generics`: generic_decl | null
*>
struct ModuleDecl
{
	inline Decl node;
	Node* path;
	NodeArray attributes;
	List{NodeID} nodes;
}

struct ImportDecl
{
	inline Decl node;
	NodeArray paths;
	NodeArray attributes;
}

struct AttributeDecl
{
	inline Decl node;
	Node* expr;
	AttributeKind attr_kind;
}

struct ErrorDecl
{
	inline Decl node;
	NodeArray fields;
}

struct ErrorUnionDecl
{
	inline Decl node;
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
	inline Decl node;
	TypeDescriptor* base_type;
	Node* generics;
	NodeArray attributes;
	bool is_inline;
}

struct FnDecl
{
	inline Decl node;
	TypeDescriptor* ret_type;
	TypeDescriptor* method_type;
	Node* body;
	NodeArray generics;
	NodeArray params;
	NodeArray attributes;
	bool is_variadic;
}

<*
 VarDecl: represents (Global, Local, Field) variables
- type: type_expr if has type
- init_expr: if has initializer
- next: Var_decl if chained (e.g. int a, b, c; )
*>
struct VarDecl
{
	inline Decl node;
	VarDeclKind var_kind;
	VarDeclFlags var_flags;
	TypeDescriptor* type;
	Node* init_expr;
	Node* next;
	NodeArray attributes;
}

struct EnumDecl
{
	inline Decl node;
	bool is_inline_backing;
	TypeDescriptor* backing_type; // optional: ":" type
	NodeArray assoc_params; // optional enum_param_list inside ":"
	NodeArray variants;
	NodeArray attributes;
}

<*
 StructDecl is both for structs & unions `is_union`
 - `generics`: generic_decl | null
*>
struct StructDecl
{
	inline Decl node;
	NodeArray fields;
	Node* type;
	Node* next;
	NodeArray attributes;
	NodeArray generics;
}
