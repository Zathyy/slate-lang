module slate::sema::resolve;

import slate::sema::lookup;

import slate::core;
import slate::lexer;

import std::math;

<*
 @require node.kind == IMPORT_DECL
*>
fn Module* resolve_import(SemaContext* ctx, Node* node)
{
	ImportDecl* imp = node.as(ImportDecl);

	foreach (Node* path_node : imp.paths)
	{
		String full_path = path_node.as(PathAtom).path.text; // e.g. "foo::bar::baz"

		if (ctx.context.modules.has_key(full_path))
		{
			Module* mod = ctx.context.modules.get(full_path)!!;

			if (try idx = full_path.rindex_of("::"))
			{
				String leaf_name = full_path[idx + 2..];

			}

			return mod;
		}
	}

	// Module not found
	return null;
}

<*
 @require node.kind == TYPE_EXPR
*>
fn Type* resolve_type(SemaContext* ctx, Node* node)
{
	if (!node) return null;

    TypeExpr* texpr = node.as(TypeExpr);
    if (!texpr) return null;

    Type* resolved = null;

    switch (texpr.type_kind)
    {
        case TYPE_IDENTIFIER:
        {
            String name = texpr.unresolved.name ? texpr.unresolved.name.text : "";

            if (texpr.unresolved.path != null)
            {
                // Qualified path like `foo::bar::MyType`
                PathAtom* path = texpr.unresolved.path.as(PathAtom);
                String fqn = string::format(ctx.alloc, "%s::%s", path.path.text, name);
                resolved = resolve_named_type_symbol(ctx, texpr.node.range, fqn);
            }
            else
            {
                // Unqualified identifier (e.g., `int`, `MyStruct`)
                resolved = resolve_named_type_symbol(ctx, texpr.node.range, name);
            }
        }

        case TYPE_POINTER:
        {
            Type* base = resolve_type(ctx, texpr.modify.base);
            if (!base) return null;

            resolved = lookup::get_or_create_pointer(ctx.context.lookup, base);
        }

        case TYPE_SLICE:
        {
            Type* elem = resolve_type(ctx, texpr.modify.base);
            if (!elem) return null;

            //resolved = lookup::get_or_create_slice(ctx.context.lookup, elem);
        }

        case TYPE_ARRAY:
        {
            Type* elem = resolve_type(ctx, texpr.array.base);
            if (!elem) return null;

            if (!texpr.array.len_expr)
            {
                diagnostics::error(ctx.context, texpr.node.range, "Inferred array size [*] is not allowed in this type declaration");
                return null;
            }

            //ulong len = evaluate_const_uint_expr(ctx, texpr.array.len_expr);
            //resolved = lookup::get_or_create_array(ctx.context.lookup, elem, len);
        }

        default:
            diagnostics::error(ctx.context, texpr.node.range, "Unhandled type expression kind");
            return null;
    }

    return resolved;
}

<*
 Resolves unqualified or module-qualified symbol names to a canonical Type*
*>
fn Type* resolve_named_type_symbol(SemaContext* ctx, Range range, String symbol_name)
{
    Lookup* lookup = ctx.context.lookup;

    if (Type* builtin = lookup.types.get(symbol_name) ?? null)
    {
        return resolve_decl_type(ctx, builtin);
    }

    String current_mod = ctx.current_module;
    String local_qname = string::format(ctx.alloc, "%s::%s", current_mod, symbol_name);

    if (Type* local_type = lookup.types.get(local_qname) ?? null)
    {
        return resolve_decl_type(ctx, local_type);
    }

    ctx.imports.@each(; name, ImportInfo info)
    {
	    String target_mod = info.path;
	    String imported_qname = string::format(ctx.alloc, "%s::%s", target_mod, symbol_name);

	    if (Type* imported_type = lookup.types.get(imported_qname) ?? null)
	    {
	        return resolve_decl_type(ctx, imported_type);
	    }
    };

    diagnostics::error(ctx.context, range, "Unknown type name '%s'", symbol_name);
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

fn Type* resolve_decl_type(SemaContext* ctx, Type* type)
{
    if (!type) return null;
    if (type.status == RESOLVED) return type;

    if (type.status == RESOLVING)
    {
        diagnostics::error(ctx.context, type.data.node.range,
            "Circular type dependency detected in '%s'", type.name);
        return null;
    }

    type.status = RESOLVING;
    Node* decl_node = type.data.node;

    switch (decl_node.kind)
    {
        case TYPEDEF_DECL:
        {
            TypedefDecl* decl = decl_node.as(TypedefDecl);
            Type* target = resolve_type(ctx, decl.base_type);

            type.kind = TYPE_ALIAS;
            type.data.ptr = target; // Alias points to underlying canonical type
            if (target)
            {
                type.size = target.size;
                type.alignment = target.alignment;
            }
        }

        case STRUCT_DECL:
        {
            StructDecl* decl = decl_node.as(StructDecl);
            type.kind = TYPE_STRUCT;

            uint current_offset = 0;
            uint max_align = 1;

            foreach (Node* field_node : decl.fields)
            {
                VarDecl* field_decl = field_node.as(VarDecl);
                Type* field_type = resolve_type(ctx, field_decl.type);
                if (!field_type) continue;

                current_offset = align_up(current_offset, field_type.alignment);
                current_offset += field_type.size;

                if (field_type.alignment > max_align) max_align = field_type.alignment;
            }

            type.size = align_up(current_offset, max_align);
            type.alignment = max_align;

            diagnostics::log_debug("'%s' has align %s, size %s", type.name, type.alignment, type.size);
        }

        default:
            break;
    }

    type.status = RESOLVED;
    return type;
}

fn void resolve_fn_signature(SemaContext* ctx, FunctionInfo* info)
{

}
