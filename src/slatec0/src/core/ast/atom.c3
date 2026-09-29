module slate::core::ast;

import std::collections::list;

struct Error
{
	inline Node node;
}

struct Ident
{
	Range range;
	String text;
}

struct PathAtom
{
	inline Node node;
	Ident* path;
	bool is_prefix;
}

<*
 Payloads:
- unresolved: TYPE_IDENTIFIER name and optional module path.
- modify: TYPE_POINTER, TYPE_REF and TYPE_SLICE base type.
- array: TYPE_ARRAY and TYPE_VECTOR base type plus length expression.
  `len_expr` is null for inferred arrays such as `Type[*]`.
- generic: TYPE_GENERIC base type and generic argument expressions.
- func: TYPE_FUNCTION return type and VAR_DECL parameter nodes.
*>
struct TypeDescriptor
{
	Type* resolved_type;
	Range range;
	TypeDescriptorKind type_kind;
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
			TypeDescriptor* base;
		}

		struct array
		{
			TypeDescriptor* base;
			Node* len_expr;
		}

		struct generic
		{
			TypeDescriptor* base;
			Node*[] params;
		}

		struct func
        {
            TypeDescriptor* return_type;
            Node*[] params;
        }
	}
}
