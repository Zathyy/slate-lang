module slate::parser;

import slate::core;

import std::collections;

fn Node* parse_path(ParseContext* ctx, bool prefix = false) => @pool()
{
	Range start = ctx.current.range;
	diagnostics::log_debug("parse_path");

	if (!ctx.is(IDENT))
	{
		if (prefix) return null;
		diagnostics::error(ctx.context, ctx.current.range, "Expected a path identifier");
		return ctx.ast.error(start);
	}

	PathAtom* node = ctx.ast.alloc_node(PathAtom, start);
	defer node.range.end = ctx.peek(-1).range.end;
	DString sb; sb.tinit();

	while (ctx.is(IDENT))
	{
		if (prefix)
		{
			if (ctx.peek(1).kind == SCOPE)
			{
				sb.append(ctx.current.value);
				sb.append("::");
				advance(ctx, 2);
			}
			else
			{
				break;
			}
		}
		else
		{
			sb.append(ctx.current.value);
			advance(ctx);

			if (consume(ctx, SCOPE))
			{
				sb.append("::");
				if (ctx.current.kind == IDENT)
				{
					continue;
				}
				else
				{
					diagnostics::error(ctx.context, ctx.current.range, "Expected an identifier after '::'");
					node.flags.has_error = true;
					break;
				}
			}
			break;
		}
	}

	node.path = ctx.ident_string(sb.str_view());
	return (Node*)node;
}

<*
 generic_param_list ::= '<' expr ( ',' expr )* '>'
*>
fn NodeArray parse_generics_list(ParseContext* ctx)
{
	if (!consume(ctx, LESS)) return {};
	List{Node*} params;
	params.init(tmem, 4);

	while (!ctx.eof())
	{
		if (ctx.is(GREATER)) break;
		// This parses 'foo::Bar' via SCOPE precedence, but STOPS before treating '>' as a greater-than comparison!
		Node* param = parse_expr(ctx, Precedence.RELATIONAL + 1);
		params.push(param);
		if (!consume(ctx, COMMA)) break;
	}

	if (!consume(ctx, GREATER))
	{
		diagnostics::error(ctx.context, ctx.current.range, "Expected closing '>' after generic parameter list");
	}

	return alloc::clone_slice(ctx.allocator, params.array_view());
}

fn Ident* parse_ident(ParseContext* ctx)
{
	if (!ctx.is(IDENT))
	{
		return null;
	}

	Ident* ident = ctx.ident(ctx.current);
	advance(ctx);

	return ident;
}
