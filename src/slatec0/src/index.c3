module slate::sema;

import slate::core;
import slate::core::visitor;

const String[*] DEFAULT_IMPORTS = {
    "std::core",
    "std::core::string",
    "std::core::env"
};

fn void index_pass(SemaContext* ctx)
{
    foreach (SourceFile* sf : ctx.context.files.value_iter())
    {
        index_source_file(ctx, sf);
    }
}

fn void index_source_file(SemaContext* ctx, SourceFile* sf)
{
    Module* mod;
    ModuleDecl* mod_decl;
    Scope* section;
    bool has_module_header = false;
    bool section_enabled = false;

    foreach (Node* node : sf.ast.statements)
    {
        if (!node.is_valid()) continue;

        if (node.kind == MODULE_DECL)
        {
            has_module_header = true;
            mod_decl = node.as(ModuleDecl);
            PathAtom* atom = mod_decl.path.as(PathAtom);

            section_enabled = true;

            mod = mod::create(ctx.context, atom.path.text);
            ctx.current_module = mod;
            section = scope::create(ctx.alloc, node.range, mod.scope);

            foreach (String path : DEFAULT_IMPORTS)
            {
                scope::add_import(section, path);
            }

            continue;
        }

        if (!has_module_header)
        {
            diagnostics::error(ctx.context, node.range, "Expected module declaration before statements");
            return;
        }

        if (!section_enabled) continue;

        ctx.node_scopes.set(node, section);
        mod::add_node(mod, node);
        mod_decl.nodes.push(node.id);

        switch (node.kind)
        {
            case IMPORT_DECL:
            {
                ImportDecl* decl = node.as(ImportDecl);
                foreach (Node* path : decl.paths)
                {
                    scope::add_import(section, path.as(PathAtom).path.text);
                }
                break;
            }
            case FN_DECL:
            case STRUCT_DECL:
            case TYPEDEF_DECL:
            case VAR_DECL:
            case ENUM_DECL:
            {
                Decl* decl = (Decl*)node;
                decl.qname = mod::get_qname(ctx.alloc, mod, decl.name.text);
                scope::define(section, decl.name.text, decl);
                diagnostics::log_info("DEFINED: %s", decl.name.text);
                break;
            }
            default:
                break;
        }
    }
}
