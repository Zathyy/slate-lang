module sema_tests @test;

import slate::core;
import slate::sema;

fn void resolve_path()
{
	CompilerContext* context = context::create();
	defer context::free(context);

	String src = `
		module std::core::env;

		enum TargetOS : u8
		{
	    Win32,
		}

		enum TargetArch : u8
		{
	    X86_64,
		}

		const bool WIN32 = TARGET_OS == TargetOS::Win32;

		const TargetOS TARGET_OS = $$TARGET_OS;
		const TargetArch TARGET_ARCH = $$TARGET_ARCH;

		//const bool TESTING = $$TESTING;
	`;

	String main_src = `
        module main;

        import std::core::env;

        fn main() {}
    `;

    log::set_priority_all(DEBUG);

	test::eq(context::process(context, src, "env.sl"), true);
	test::eq(context::process(context, main_src, "main.sl"), true);

	SemaContext* sema = sema::create(context);
	sema::run_pipeline(sema);
}
