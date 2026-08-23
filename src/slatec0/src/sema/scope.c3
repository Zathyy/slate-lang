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
fn Decl* lookup(Scope* scope, String name)
{
    Scope* current = scope;
    while (current != null)
    {
        if (current.symbols.has_key(name))
        {
            return current.symbols.get(name)!!;
        }
        current = current.parent;
    }

    return null;
}

<*
 Check if a symbol exists anywhere in the scope hierarchy.
*>
fn bool Scope.has(Scope* scope, String name)
{
    return scope::lookup(scope, name) != null;
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
