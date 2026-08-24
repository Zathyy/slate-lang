module slate;

import std::io;
import seali;
import std::os;

import std::collections;

$expand(seali::@derive(Cli));
struct Cli @Command({.name = "slatec", .about = "Slate compiler"})
{
	Maybe{Compile} compile @Seali(arg(subcommand));
	Maybe{CompileRun} compile_run @Seali(arg(subcommand));
	bool json @Seali(arg(short = 'j', long, default_value = false, help = "output ast as json"));
}

struct Compile @Command({.name = "compile", .about = "Compile target"})
{
	String path @Seali(arg(help = "Path to sources"));
}

struct CompileRun @Command({.name = "compile-run", .about = "Compile target and run"})
{
	String path @Seali(arg(help = "Path to sources"));
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
	bool run_after = false;
	if (try value = cli.compile.get())
	{
		process_sources(context, value.path);
	}
	else if (try value = cli.compile_run.get())
	{
		process_sources(context, value.path);
		run_after = true;
	}

	SemaContext* sema = sema::create(context);
	sema::run_pipeline(sema);
	if (context.error_count > 0)
	{
		diagnostics::log_error("Analysis pipeline had errors, exiting...");
		os::exit(1);
	}

	if (cli.json)
	{
		String path = string::tformat("%s/debug/ast.json", globals::build_path);
		path::mkdir(string::tformat("%s/debug/", globals::build_path), true)!!;
		File file = file::open(path, "w")!!;
		context.modules.@each(; String name, Module* mod)
		{
			foreach (Node* node : mod.nodes)
			{
				String str = node.serialize(indent: 4);
				file.write(str)!!;
			};
		};
	}

	CodegenContext* cg = codegen::create(context);
	String path = utils::get_msvc_sdk(context.alloc);

	foreach (Module* mod : context.modules.value_iter())
	{
		if (!codegen::emit_module(cg, mod))
		{
			os::exit(1);
		}
	}

	Module* main_mod = context.modules.get("main")!!;

	LinkerContext* linker = linker::create(context);
	String exe = linker::link(linker, main_mod)!!;

	if (!run_after) return;
	diagnostics::log_info("[Runner]: Executing '%s'", exe);
 	String[*] args = {
  		exe
    };

    Process proc = process::spawn(&args, INHERIT_ENV | INHERIT_STDIO)!!;
    defer (void)proc.destroy();
    int exit_code = proc.join()!!;
    diagnostics::log_info("[Runner]: Completed with exit code '%d'", exit_code);
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

fn void process_sources(CompilerContext* context, String path)
{
	path::traverse((Path)path, fn bool?(path, is_dir, data) {
        CompilerContext* context = (CompilerContext*)data;

        if (!is_dir && path.has_extension("sl"))
        {
            context::process_file(context, path);
        }

        return false;
    }, context)!!;
}
