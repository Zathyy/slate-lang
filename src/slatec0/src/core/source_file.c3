module slate::core::source_file;

import slate::lexer;
import slate::parser;
import slate::core::context;

import std::io;

FileID next_file_id @private = (FileID)1;

fn SourceFile* create(CompilerContext* context, Lexer* lexer, String path)
{
	SourceFile* source_file = alloc::new(context.alloc, SourceFile);

	source_file.content = lexer.buffer;
	source_file.lexer = lexer;

	Allocator alloc = &context::g_arena;

	source_file.ast.nodes.init(alloc);
	source_file.ast.statements.init(alloc);
	source_file.path = path.copy(alloc);

	FileID id = next_file_id++;
	source_file.id = id;
	context.files.set(id, source_file);
	context.current_source_file = id;

	return source_file;
}

fn SourceFile* get(CompilerContext* ctx, FileID id)
{
    return ctx.files.get(id)!!;
}

fn Range get_range(SourceFile* sf) => @pool()
{
	String[] lines = sf.content.tsplit("\n");

	Range range = {
		.start = {},
		.end = {
		    .line = lines.len - 1,
			.column = lines[^1].len - 1
		},
		.file_id = sf.id
	};

	return range;
}
