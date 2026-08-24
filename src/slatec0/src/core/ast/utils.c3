module slate::core::ast;

<*
 Extracts the raw, un-prefixed identifier string from a TYPE_EXPR node.
 Example: 'List*' -> 'List'
*>
fn String? raw_type_identifier(Node* node)
{
	if (!node.is_valid() || node.kind != TYPE_EXPR) return NOT_FOUND~;

	Node* current = node;

	while (current && current.kind == TYPE_EXPR)
	{
		TypeExpr* data = current.as(TypeExpr);

		switch (data.type_kind)
		{
			case TYPE_IDENTIFIER:
			{
				if (!data.unresolved.name) return "";
				return data.unresolved.name.text;
			}
			case TYPE_POINTER:
			case TYPE_SLICE:
				current = data.modify.base;
				break;
			case TYPE_ARRAY:
			case TYPE_VECTOR:
				current = data.array.base;
				break;
			case TYPE_GENERIC:
				current = data.generic.base;
				break;
			default:
		}
	}

	return NOT_FOUND~;
}

fn String? type_identifier(Allocator alloc, Node* node) => @pool()
{
	if (!node) return "";
	if (!node.is_valid() || node.kind != TYPE_EXPR) return NOT_FOUND~;

	DString sb; sb.tinit();

	if (node.flags.is_const)
	{
		sb.append("const ");
	}

	sb.append(raw_type_identifier(node) ?? "unknown");

	Node* current = node;

	while (current && current.kind == TYPE_EXPR)
	{
		TypeExpr* data = current.as(TypeExpr);

		switch (data.type_kind)
		{
			case TYPE_IDENTIFIER:
			{
				return sb.copy_str(alloc);
			}
			case TYPE_POINTER:
				current = data.modify.base;
				sb.append("*");
				break;
			case TYPE_SLICE:
				current = data.modify.base;
				sb.append("[]");
				break;
			case TYPE_ARRAY:
				current = data.array.base;
				sb.append("[x]");
				break;
			case TYPE_GENERIC:
				sb.append("<>");
				current = data.generic.base;
				break;
			default:
				break;
		}
	}

	return NOT_FOUND~;
}
