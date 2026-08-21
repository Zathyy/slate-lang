module slate::core::source_file;

import slate::lexer;
import slate::parser;
import slate::core::context;

import std::io;

fn SourceFile* create(CompilerContext* context, Lexer* lexer, String path)
{
	SourceFile* source_file = alloc::new(context.alloc, SourceFile);

	source_file.content = lexer.buffer;
	source_file.lexer = lexer;

	Allocator alloc = &context::g_arena;

	source_file.ast.nodes.init(alloc);
	source_file.ast.statements.init(alloc);
	source_file.path = path.copy(alloc);

	context.files.set(source_file.path, source_file);

	return source_file;
}
