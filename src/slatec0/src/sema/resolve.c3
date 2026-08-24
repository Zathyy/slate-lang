module slate::sema;

import slate::sema::lookup;
import slate::sema::scope;

import slate::core;
import slate::lexer;

import llvm;
import std::math;
import std::collections;

<*
 Resolves both simple ("foo") and qualified ("env:WIN32") identifier paths.
*>
fn Decl* resolve_path(SemaContext* ctx, Scope* current_scope, String path) => @pool()
{
	sz last_sep = path.rindex_of("::") ?? -1;
	if (last_sep == -1)
	{
		return scope::lookup(ctx, current_scope, path);
	}
	diagnostics::log_error("[resolve_path]: last_sep: %d", last_sep);
	diagnostics::log_error("[resolve_path]: path: %s", path);

	String prefix = path[0 .. last_sep - 1];
	String target_symbol = path[last_sep + 2..^1];

	diagnostics::log_error("[resolve_path]: prefix: %s", prefix);
	diagnostics::log_error("[resolve_path]: symbol: %s", target_symbol);

	String target_mod_name = current_scope.get_import(prefix);
	diagnostics::log_error("[resolve_path]: target_mod_name: %s", target_mod_name);
	if (target_mod_name.len == 0 && ctx.context.modules.has_key(prefix))
	{
		target_mod_name = prefix;
	}

	if (target_mod_name.len > 0)
	{
		if (Module* target_mod = ctx.context.modules.get(target_mod_name) ?? null)
		{
			return target_mod.find_decl(target_symbol);
		}
	}

	return null;
}

<*
 Rounds an offset or size up to the nearest multiple of 'alignment'.
 @require math::is_power_of_2(alignment) : `alignment must be power of 2`
*>
fn uint align_up(uint value, uint alignment) @inline
{
	if (alignment <= 1) return value;
	return (value + alignment - 1) & ~(alignment - 1);
}

fn Type* resolve_type_by_name(SemaContext* ctx, Scope* scope, String name)
{
	// Check built-ins or cached primitive types in Lookup ("i32", "u8", "void", etc.)
	if (Type* t = ctx.context.lookup.types.get(name) ?? null)
	{
		return t;
	}

	//  Resolve via Scope or qualified module path ("MyStruct", "std::core::String")
	if (Decl* decl = resolve_path(ctx, scope, name))
	{
		if (decl.node.kind == TYPEDEF_DECL)
		{
			TypedefDecl* t_decl = (TypedefDecl*)decl;
			return resolve_type(ctx, scope, t_decl.base_type);
		}

		if (decl.resolved_type != null)
		{
			return decl.resolved_type;
		}

		// Fallback to node_types table if stored separately on the AST node
		if (Type* t = get_type(ctx, (Node*)decl) ?? null)
		{
			return t;
		}
	}

	diagnostics::log_error("[Sema]: Unknown type identifier '%s'", name);
	return null;
}

fn Type* resolve_type(SemaContext* ctx, Scope* scope, Node* type)
{
	if (type == null) return null;

	switch (type.kind)
	{
		case IDENT_EXPR:
		{
			IdentExpr* ident = type.as(IdentExpr);
			String name = ident.ident.text;
			return resolve_type_by_name(ctx, scope, name);
		}
		case TYPE_EXPR:
		{
			TypeExpr* type_expr = type.as(TypeExpr);
			switch (type_expr.type_kind)
			{
				case TYPE_IDENTIFIER:
				{
					String name = type_expr.unresolved.name.text;
					return resolve_type_by_name(ctx, scope, name);
				}

				case TYPE_POINTER:
				{
					Type* base = resolve_type(ctx, scope, type_expr.modify.base);
					return lookup::get_or_create_pointer(ctx.context.lookup, base);
				}

				case TYPE_ARRAY:
				{
					Type* elem = resolve_type(ctx, scope, type_expr.array.base);

					ulong len = 0;
					if (type_expr.array.len_expr != null)
					{
						len = eval_const_int(ctx, type_expr.array.len_expr);
					}

					return lookup::get_or_create_array(ctx.context.lookup, elem, len);
				}

				case TYPE_SLICE:
				{
					Type* elem = resolve_type(ctx, scope, type_expr.array.base);
					return lookup::get_or_create_slice(ctx.context.lookup, elem);
				}

				default:
					diagnostics::log_error("[Sema]: Unsupported TypeExpr kind");
					return null;
			}
		}
		default:
			diagnostics::log_error("Unknown type kind: %s", type.kind.description);
			unreachable("");
	}
}
