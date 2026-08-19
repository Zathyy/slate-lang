module slate;

import std::io;
import seali;

//enum Action
//{
//	COMPILE,
//}//

//$expand(seali::@derive(Cli));
//struct Cli @Command({.name = "slatec", .about = "Slate compiler"})
//{
//
//}

fn int main(String[] args) => @pool()
{
	log::set_priority_all(DEBUG);

	CompilerContext* context = context::create();
	defer context::free(context);

	path::mkdir("build")!!;
	path::mkdir("build/obj")!!;
	path::mkdir("build/ir")!!;

	process_stdlib(context);

	compile(context);

	return 0;
}

fn void compile(CompilerContext* context)
{
	SemaContext* sema = sema::create(context);
	sema::index(sema);
	sema::analyze(sema);
}

fn void process_stdlib(CompilerContext* context) => @pool()
{
    String exe = utils::get_executable_path();
    if (!exe)
    {
   		diagnostics::log_error("Failed to retrieve exe path");
     	return;
    }
    defer exe.free(mem);

    String root_dir;

    Path current = (Path)exe;
    while (true)
    {
     	if (path::is_dir((Path)string::tformat("%s/lib", current)))
		{
			root_dir = current;
			break;
		}

		Path? new_path = current.parent();
		if (catch new_path) break;
		current = new_path;
    }


    Path stdlib = string::tformat("%s/lib/std", ((Path)root_dir)).to_path(context.alloc)!!;

    diagnostics::log_info("stdlib path = %s", stdlib);

    path::traverse(stdlib, fn bool?(path, is_dir, data) {
        CompilerContext* context = (CompilerContext*)data;

        if (!is_dir && path.has_extension("sl"))
        {
            context::process_file(context, path);
        }

        return false;
    }, context)!!;
}
