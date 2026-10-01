module slate;

import std::io;
import seali;
import std::os;

import std::collections;

import slate::emitter;
import slate::sema;

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

	path::mkdir("build")!!;
	path::mkdir("build/obj")!!;
	path::mkdir("build/ir")!!;

	path::chdir(globals::root_path)!!;

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
    sema::index_pass(sema);

    if (context.error_count > 0)
    {
        diagnostics::log_error("Indexing had errors, exiting...");
        os::exit(1);
    }

	// Ensure build/ir directory exists
    path::mkdir(string::tformat("%s/ir", globals::build_path), true)!!;
    String c_file_path = string::tformat("%s/ir/output.c", globals::build_path);
    String exe_path = string::tformat("%s/slate_out.exe", globals::build_path); // Use .bin/.out on Linux

    // Open file to write generated C code
    File c_file = file::open(c_file_path, "w")!!;

    c_file.write("#include <stdio.h>\n")!!;
    c_file.write("#include <stdint.h>\n")!!;
    c_file.write("#include <stdbool.h>\n\n")!!;

    c_file.write("typedef size_t usize;\n")!!;

    c_file.write("typedef uint32_t typeid;\n")!!;

    c_file.write("typedef uint8_t u8;\n")!!;
    c_file.write("typedef uint16_t u16;\n")!!;
    c_file.write("typedef uint32_t u32;\n")!!;
    c_file.write("typedef uint64_t u64;\n")!!;
    c_file.write("typedef int8_t i8;\n")!!;
    c_file.write("typedef int16_t i16;\n")!!;
    c_file.write("typedef int32_t i32;\n")!!;
    c_file.write("typedef int64_t i64;\n\n")!!;

    foreach (Module* mod : context.modules.value_iter())
    {
    	emitter::begin(sema, mod);
        foreach (Node* node : mod.nodes)
        {
            emitter::forward_declare(node, &c_file);
        }
    }
    c_file.write("\n")!!;

    foreach (Module* mod : context.modules.value_iter())
    {
        log::info("Emitting C for Module: %s", mod.name);
       	emitter::begin(sema, mod);

        foreach (Node* node : mod.nodes)
        {
            emitter::emit_node_to_c(node, &c_file);
        }
    }

    c_file.close();

    diagnostics::log_info("Successfully generated C file at: %s", c_file_path);

    diagnostics::log_info("Compiling generated C code with host compiler...");

    diagnostics::log_info("Generating executable to %s", exe_path);

    String[*] gcc_args = {
        "clang",
        "-x",
        "c",
        c_file_path,
        "-o",
        exe_path,
        "-O0",                 // Disable optimizations so main isn't stripped/optimized
    };

    Process proc = process::spawn(&gcc_args, INHERIT_ENV | INHERIT_STDIO)!!;
    defer (void)proc.destroy();
    int exit_code = proc.join()!!;

    if (exit_code != 0)
    {
        diagnostics::log_error("Host C compiler failed with exit code %d", exit_code);
        os::exit(1);
    }

    diagnostics::log_info("Build complete! Executable created at: %s", exe_path);

    if (!run_after) return;

    diagnostics::log_info("[Runner]: Executing '%s'", exe_path);
    String[*] run_args = { exe_path };

    Process run_proc = process::spawn(&run_args, INHERIT_ENV | INHERIT_STDIO)!!;
    defer (void)run_proc.destroy();
    int run_exit_code = run_proc.join()!!;
    diagnostics::log_info("[Runner]: Completed with exit code '%d'", run_exit_code);
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
