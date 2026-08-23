module slate;

import std::io;
import seali;

enum Action
{
	COMPILE,
	COMPILER_RUN,
}

$expand(seali::@derive(Cli));
struct Cli @Command({.name = "slatec", .about = "Slate compiler"})
{
	String src;
}

Cli cli;

fn int main(String[] args) => @pool()
{
	log::set_priority_all(DEBUG);

	cli.parse(args)!!;

	CompilerContext* context = context::create();
	defer context::free(context);

	find_root_path(context);

	path::chdir(globals::root_path)!!;

	path::mkdir("build")!!;
	path::mkdir("build/obj")!!;
	path::mkdir("build/ir")!!;

	Path cwd = path::tcwd()!!;

	globals::build_path = cwd.append(context.alloc, "build")!!;
	globals::obj_path = cwd.append(context.alloc, "build/obj")!!;
	globals::ir_path = cwd.append(context.alloc, "build/ir")!!;

	diagnostics::log_info("Set build_path %s", globals::build_path);
	diagnostics::log_info("Set obj_path %s", globals::obj_path);
	diagnostics::log_info("Set ir_path %s", globals::ir_path);

	process_stdlib(context);

	compile(context);

	return 0;
}

fn void find_root_path(CompilerContext* context)
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

	globals::root_path = root_dir.copy(context.alloc);
}

fn void compile(CompilerContext* context)
{
	path::traverse((Path)cli.src, fn bool?(path, is_dir, data) {
        CompilerContext* context = (CompilerContext*)data;

        if (!is_dir && path.has_extension("sl"))
        {
            context::process_file(context, path);
        }

        return false;
    }, context)!!;

	SemaContext* sema = sema::create(context);
	sema::run_pipeline(sema);

	CodegenContext* cg = codegen::create(context);
	String path = utils::get_msvc_sdk(context.alloc);

	foreach (Module* mod : context.modules.value_iter())
	{
		codegen::emit_module(cg, mod);
	}

	Module* main_mod = context.modules.get("main")!!;

	LinkerContext* linker = linker::create(context);
	linker::link(linker, main_mod)!!;
}

fn void process_stdlib(CompilerContext* context) => @pool()
{
    Path stdlib = string::tformat("%s/lib/std", ((Path)globals::root_path)).to_path(context.alloc)!!;

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
