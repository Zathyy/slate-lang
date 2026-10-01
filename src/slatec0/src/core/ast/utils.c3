module slate::core::ast;

<*
 Extracts the raw, un-prefixed identifier string from a TYPE_EXPR node.
 Example: 'List*' -> 'List'
*>
fn String? raw_type_identifier(TypeDescriptor* type)
{
	TypeDescriptor* current = type;

	while (current)
	{
		switch (current.type_kind)
		{
			case TYPE_IDENTIFIER:
			{
				if (!current.unresolved.name) return "";
				return current.unresolved.name.text;
			}
			case TYPE_POINTER:
			case TYPE_SLICE:
				current = current.modify.base;
				break;
			case TYPE_ARRAY:
			case TYPE_VECTOR:
				current = current.array.base;
				break;
			case TYPE_GENERIC:
				current = current.generic.base;
				break;
			default:
		}
	}

	return NOT_FOUND~;
}

fn String type_to_c_string(TypeDescriptor* type)
{
    if (!type) return "void";

    TypeDescriptor* current = type;
    DString sb;
    sb.tinit();

    switch (current.type_kind)
    {
        case TYPE_IDENTIFIER:
        {
            if (!current.unresolved.name) return "int";
            return current.unresolved.name.text;
        }
        case TYPE_POINTER:
        {
            String base_str = type_to_c_string(current.modify.base);
            return string::tformat("%s*", base_str);
        }
        case TYPE_SLICE:
        {
            String base_str = type_to_c_string(current.modify.base);
            return string::tformat("%s*", base_str);
        }
        case TYPE_ARRAY:
        {
            String base_str = type_to_c_string(current.array.base);
            return string::tformat("%s*", base_str);
        }
        default:
            return "int";
    }
}
