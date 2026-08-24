module slate::sema::scope;

import slate::core;

fn Scope* create(Allocator alloc, Range range, Scope* parent = null)
{
	Scope* scope = alloc::new(alloc, Scope);

	scope.parent = parent;
	scope.range = range;
	scope.children.init(alloc);
	scope.symbols.init(alloc);
	scope.imports.init(alloc);

	if (parent)
    {
        parent.children.push(scope);
    }

	return scope;
}

fn bool define(Scope* scope, String name, Decl* decl)
{
    if (scope.symbols.has_key(name))
    {
        return false; // Collision in current scope!
    }

    scope.symbols.set(name, decl);
    return true;
}

<*
 Look up a declaration by walking up the parent scope chain.
*>
fn Decl* lookup(SemaContext* ctx, Scope* scope, String name)
{
    Scope* current = scope;
    while (current != null)
    {
        if (current.symbols.has_key(name))
        {
            return current.symbols.get(name)!!;
        }

		foreach (String import_path : current.imports)
		{
		    Module* imported_mod = ctx.context.modules.get(import_path) ?? null;
		    if (imported_mod != null && imported_mod.scope != null)
		    {
		        if (imported_mod.scope.symbols.has_key(name))
		        {
		            return imported_mod.scope.symbols.get(name)!!;
		        }
		    }
		}

        current = current.parent;
    }

    return null;
}

<*
 Check if a symbol exists anywhere in the scope hierarchy.
*>
fn bool has(SemaContext* ctx, Scope* scope, String name)
{
    return scope::lookup(ctx, scope, name) != null;
}

fn void add_import(Scope* scope, String name)
{
	scope.imports.push(name);
}

fn String Scope.get_import(Scope* scope, String name) => @pool()
{
    Scope* current = scope;
    while (current != null)
    {
        foreach (String imp : current.imports)
        {
            if (imp == name) return imp;

            if (imp.ends_with(string::tformat("::%s", name)))
            {
            	return imp;
            }
        }
        current = current.parent;
    }

    return "";
}

fn Scope* find_innermost_scope(Scope* current, Range target_range)
{
    foreach (Scope* child : current.children)
    {
        if (child.range.contains_range(target_range))
        {
            return find_innermost_scope(child, target_range);
        }
    }
    return current;
}
