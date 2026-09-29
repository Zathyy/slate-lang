module slate::sema::util;

import slate::core;

fn bool has_attribute(Node* node, AttributeKind kind, Node** out_attribute)
{
	NodeArray temp;
	switch (node.kind)
	{
		case MODULE_DECL:
			ModuleDecl* s = node.as(ModuleDecl);
			temp = s.attributes;
			break;
		case STRUCT_DECL:
			StructDecl* s = node.as(StructDecl);
			temp = s.attributes;
			break;
		case FN_DECL:
			FnDecl* func = node.as(FnDecl);
			temp = func.attributes;
			break;
		default:
			return false;
	}

	foreach (attr : temp)
	{
		AttributeDecl* attr_decl = attr.as(AttributeDecl);
		if (attr_decl && attr_decl.attr_kind == kind)
		{
			if (out_attribute)
			{
				*out_attribute = attr;
			}

			return true;
		}
	}

	return false;
}

fn bool is_comparison_op(OperatorKind op)
{
    switch (op)
    {
        case OP_EQ:   // ==
        case OP_NE:  // !=
        case OP_LT:   // <
        case OP_LE:  // <=
        case OP_GT:   // >
        case OP_GE:  // >=
            return true;

        default:
            return false;
    }
}

fn bool is_lvalue(Node* node)
{
    if (node == null) return false;

    switch (node.kind)
    {
        case IDENT_EXPR:
        case ACCESS_EXPR:  // e.g. obj.field
        case UNARY_EXPR:   // e.g. *ptr (dereference)
            return true;
        default:
            return false;
    }
}
