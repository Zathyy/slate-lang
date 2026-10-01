module slate::core::context;

import slate::core::ast;
import slate::core::mod;
import slate::core::diagnostics;
import slate::core::source_file;
import slate::lexer;
import slate::parser;
import slate::core::arch;
import slate::core::os;

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

	g_arena.init(mem, 4096);

	ctx.files.init(ctx.alloc);
	ctx.modules.init(ctx.alloc);
	ctx.features.init(ctx.alloc);

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

	ctx.features.push("WIN32");
	ctx.features.push("X86_64");
	ctx.features.push("LIBC");

	return ctx;
}

fn void free(CompilerContext* ctx)
{
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
