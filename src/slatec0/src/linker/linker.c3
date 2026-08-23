module slate::linker;

import slate::core;
import std::io;
import std::os::process;

import slate::utils;

import llvm;

faultdef
	OBJECT_EMISSION_FAILED,
	MODULE_LINK_FAILED,
	LINKER_EXEC_FAILED;

struct LinkerContext
{
	CompilerContext* context;
}

fn LinkerContext* create(CompilerContext* context)
{
	LinkerContext* linker = alloc::new(context.alloc, LinkerContext);

	linker.context = context;

	return linker;
}

<*
 @param [&in] dst
 @param [&inout] src
*>
fn void? link_modules(LinkerContext* ctx, Module* dst, Module* src)
{
	if (dst.llvm_module == null || src.llvm_module == null)
    {
        return MODULE_LINK_FAILED~;
    }

	if (llvm::link_modules_2(dst.llvm_module, src.llvm_module) != 0)
	{
		diagnostics::log_error("[Linker]: Failed to link module '%s' into '%s'", src.name, dst.name);
		return MODULE_LINK_FAILED~;
	}

	src.llvm_module = null;
}

fn void? link_all(LinkerContext* ctx, Module* main_module)
{
	foreach (Module* mod : ctx.context.modules.value_iter())
	{
		if (mod == main_module) continue;
		diagnostics::log_debug("[Linker]: Merging '%s' -> '%s'", mod.name, main_module.name);
		link_modules(ctx, main_module, mod)!;
	}
}

fn void? link_executable(LinkerContext* ctx, String obj_path)
{
    diagnostics::log_info("[Linker]: Invoking lld-link...");

    // Construct winsysroot parameter
    String sysroot_flag = string::tformat("/winsysroot:%s", utils::get_msvc_sdk(tmem));
    String out_flag     = string::tformat("/out:%s%s", globals::build_path, "target.exe");

    String[*] args = {
        "lld-link",
        "/nologo",
        sysroot_flag,
        out_flag,
        "/subsystem:console",
        "/defaultlib:libcmt",      // CRT static runtime
        "/defaultlib:oldnames",
        obj_path
    };

    // Spawn lld-link process
    Process proc = process::spawn(&args, INHERIT_ENV | INHERIT_STDIO)!!;
    defer (void)proc.destroy();
    int exit_code = proc.join()!;

    if (exit_code != 0)
    {
        diagnostics::log_error("[Linker]: lld-link failed with exit code %d", exit_code);
        return LINKER_EXEC_FAILED~;
    }

    diagnostics::log_info("[Linker]: Successfully created '%s'", out_flag[5..]);
}

fn void? emit_object_file(LinkerContext* ctx, Module* main_module, String obj_path)
{
	assert(main_module.llvm_module != null);

    diagnostics::log_info("[Linker]: Emitting object file to '%s'", obj_path);

    LLVMTargetMachineRef target_machine = ctx.context.llvm_target;
    LLVMBool fail = llvm::target_machine_emit_to_file(
        target_machine,
        main_module.llvm_module,
        (CChar*)obj_path.ptr,
        OBJECT_FILE,
        null
    );

    if (fail != 0)
    {
        diagnostics::log_error("[Linker]: Failed to emit target object file");
        return OBJECT_EMISSION_FAILED~;
    }
}

fn void? link(LinkerContext* ctx, Module* main_module)
{
    link_all(ctx, main_module)!;

    String obj_path = globals::obj_path.concat(tmem, "main.obj");

    String ir_path = ((Path)globals::ir_path).tappend("out.ir")!!;

    dump_ir_to_file(main_module, ir_path);

    emit_object_file(ctx, main_module, obj_path)!;

    link_executable(ctx, obj_path)!;
}

fn void dump_ir_to_file(Module* mod, String path)
{
    CChar* err_msg = null;
    if (llvm::print_module_to_file(mod.llvm_module, (CChar*)path.ptr, &err_msg) != 0)
    {
        diagnostics::log_error("[Linker]: Failed to dump IR: %s", (ZString)err_msg);
        if (err_msg != null) llvm::dispose_message(err_msg);
        return;
    }
    diagnostics::log_info("[Linker]: Dumped LLVM IR to '%s'", path);
}
