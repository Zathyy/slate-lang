module slate::sema;

import slate::core;
import slate::core::visitor;

fn void body_pass(SemaContext* ctx)
{
    foreach (SourceFile* sf : ctx.context.files.value_iter())
    {
        ctx.context.current_source_file = sf;

        foreach (Node* statement : sf.ast.statements)
        {
            if (!statement || statement.kind != FN_DECL) continue;

            FnDecl* decl = statement.as(FnDecl);
            //if (!decl.is_generic)
            //{
                //check_fn_body(ctx, decl);
            //}
        }
    }
}
