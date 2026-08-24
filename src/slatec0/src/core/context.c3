module slate::core::context;

import slate::core::ast;
import slate::core::mod;
import slate::core::diagnostics;
import slate::core::source_file;
import slate::lexer;
import slate::parser;
import slate::core::arch;
import slate::core::os;
import slate::sema;

import llvm;

import std::io;

faultdef
    TARGET_INIT_FAILED,
    TARGET_MACHINE_CREATION_FAILED;

DynamicArenaAllocator g_arena;

<*
 If target.os or target.arch is `UNKNOWN` it will be inferred
*>
fn CompilerContext* create(Target target = {})
{
	CompilerContext* ctx = alloc::new(mem, CompilerContext);
	ctx.alloc = &g_arena;

	ctx.llvm_context = llvm::context_create();
	ctx.llvm_target = create_target_machine()!!;

	g_arena.init(mem, 4096);

	ctx.files.init(ctx.alloc);
	ctx.modules.init(ctx.alloc);

	if (target.arch == UNKNOWN)
	{
		target.arch = arch::current();
	}

	if (target.os == UNKNOWN)
	{
		target.os = os::current();
	}
	ctx.target = target;
	ctx.target.layout = arch::get_platform_layout(target.os, target.arch);

	ctx.lookup = lookup::create(ctx);

	return ctx;
}

fn void free(CompilerContext* ctx)
{
	llvm::context_dispose(ctx.llvm_context);
	mem::free(ctx);
	g_arena.free();
}

<*
 process from a buffer
 @param path : "uri/path to the file or 'virtual' file"
 @require buffer.len > 0
*>
fn bool process(CompilerContext* context, String buffer, String path) => @pool()
{
	diagnostics::log_info("processing file: %s", path);
	Lexer* lexer = lexer::create(context, buffer);
	SourceFile* source = source_file::create(context, lexer, path);

	lexer::tokenize(lexer);

	ParseContext* parse_ctx = parser::create(context);

	if (!parser::parse(parse_ctx, source))
	{
		return false;
	}

	return true;
}

fn bool process_file(CompilerContext* context, String path) => @pool()
{
	String? buffer = (String)file::load(tmem, path);
	if (catch err = buffer)
	{
		diagnostics::log_error("core::process_file - failed to load file (&s) %s", err, path);
		return false;
	}

	return process(context, buffer, path);
}

fn LLVMTargetMachineRef? create_target_machine()
{
    llvm::initialize_X86_target();
    llvm::initialize_X86_target_info();
    llvm::initialize_X86_target_mc();
    llvm::initialize_X86_asm_printer();
    llvm::initialize_X86_asm_parser();

    CChar* triple = llvm::get_default_target_triple();

    LLVMTargetRef target = null;
    CChar* error_msg = null;
    if (llvm::get_target_from_triple(triple, &target, &error_msg) != 0)
    {
        diagnostics::log_error("[LLVM]: Failed to resolve target triple: %s", (ZString)error_msg);
        llvm::dispose_message(error_msg);
        llvm::dispose_message(triple);
        return TARGET_INIT_FAILED~;
    }

    CChar* cpu = llvm::get_host_cpu_name();
    CChar* features = llvm::get_host_cpu_features();

    LLVMTargetMachineRef target_machine = llvm::create_target_machine(
        target,
        triple,
        cpu,
        features,
        CODE_GEN_LEVEL_NONE,  // None, Less, Default, Aggressive
        RELOC_DEFAULT,        // Default (PIC for Windows x64)
        CODE_MODEL_DEFAULT
    );

    llvm::dispose_message(triple);
    llvm::dispose_message(cpu);
    llvm::dispose_message(features);

    if (target_machine == null)
    {
        diagnostics::log_error("[LLVM]: Failed to create Target Machine.");
        return TARGET_MACHINE_CREATION_FAILED~;
    }

    return target_machine;
}
