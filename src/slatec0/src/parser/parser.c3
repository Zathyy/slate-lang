module slate::parser;

import slate::core;
import slate::lexer;

<*
 @param [&in] context : "The main context"
*>
fn ParseContext* create(CompilerContext* context)
{
	ParseContext* ctx = alloc::new(&context::g_arena, ParseContext);
	ctx.context = context;
	ctx.allocator = &context::g_arena;
	return ctx;
}

fn Token ParseContext.peek(&self, int pos) @inline
{
	if (self.pos + pos >= (int)self.lexer.tokens.len())
	{
		return self.lexer.tokens.last()!!;
	}
	if (self.pos + pos < 0)
	{
		return self.lexer.tokens.first()!!;
	}
	return self.lexer.tokens[(sz)self.pos + pos];
}

fn bool ParseContext.eof(&self) @inline => self.pos >= self.lexer.tokens.len() || self.current.is_eof();

fn bool ParseContext.is(&self, TokenKind kind) @inline => self.peek(0).kind == kind;

fn void skip_until(ParseContext* ctx, TokenKind[] targets, bool skip_matching = false)
{
	int brace_depth = 0;
	while (!ctx.eof())
	{
		if (ctx.is(LBRACE)) brace_depth++;
		if (ctx.is(RBRACE)) brace_depth--;

		// Target check (only stop if not inside a nested structure)
		if (brace_depth <= 0)
		{
			foreach (TokenKind target : targets)
			{
				if (ctx.is(target))
				{
					if (skip_matching)
					{
						advance(ctx);
					}
					return;
				}
			}
		}

		if (brace_depth < 0) return;

		advance(ctx);
	}
}

<*
 make a ident from token
 Note: Does not advance
*>
fn Ident* ParseContext.ident(&self, Token t) @inline
{
	Ident* ident = alloc::new(&context::g_arena, Ident);
	*ident = {
		.range = t.range,
		.text = t.value.copy(&context::g_arena)
	};

	return ident;
}

fn Ident* ParseContext.ident_string(&self, String str) @inline
{
	Ident* ident = alloc::new(&context::g_arena, Ident);
	*ident = {
		.text = str.copy(&context::g_arena)
	};
	return ident;
}

<*
 @param [&in] ctx
 @param [&inout] node : "Node to flag with error"
 @param [&inout] ctx : "The kind to expect"
*>
macro Token expect(ParseContext* ctx, Node* node, TokenKind kind)
{
	if (ctx.is(kind))
	{
		advance(ctx);
		return ctx.peek(-1);
	}

	diagnostics::error(ctx.context, ctx.current.range,
		"Expected '%s' got '%s'", kind.description, ctx.current.kind.description);
	diagnostics::log_error("Happened here.");
	node.flags.has_error = true;
	ctx.error_count++;
	return {
		.kind = ERROR,
		.range = ctx.current.range,
		.value = "<error>"
	};
}

<*
 @param [&inout] ctx
*>
macro void @expect(ParseContext* ctx, TokenKind kind; @body())
{
	if (ctx.is(kind))
	{
		advance(ctx);
		return;
	}

	@body();
}

<*
 @param [&inout] ctx
 @param kind : "type to consume"
*>
fn bool consume(ParseContext* ctx, TokenKind kind)
{
	if (ctx.is(kind))
	{
		advance(ctx);
		return true;
	}

	return false;
}

<*
 @param [&inout] ctx
*>
fn void advance(ParseContext* ctx, int len = 1)
{
	if (ctx.eof())
	{
		diagnostics::log_debug("parser::advance() : eof");
	}

	ctx.pos += len;

	if (ctx.pos >= ctx.lexer.tokens.len())
	{
		ctx.pos = (int)ctx.lexer.tokens.len() - 1;
	}

	ctx.current = ctx.lexer.tokens[ctx.pos];
}

<*
 Parse specified source file
 expects tokens to be ready, a call to lexer.tokenize()
 will return false if the last token is not a EOF token

 @param [&inout] ctx
 @param [&in] source_file
 @require source_file.lexer != null
 @require source_file.lexer.tokens.len() > 0
 @return "true if succeeded"
*>
fn bool parse(ParseContext* ctx, SourceFile* source_file) => @pool()
{
	ctx.lexer = source_file.lexer;
	ctx.ast = &source_file.ast;
	ctx.context.current_source_file = source_file;

	if (ctx.lexer.tokens.last()!!.kind != EOF)
	{
		diagnostics::log_error(
			"The last token in the lexer has to be a EOF token. Got: %s",
			ctx.lexer.tokens.last()!!.kind.description);
		return false;
	}

	ctx.current = ctx.lexer.tokens[0];

	while (!ctx.eof())
	{
		int pos = ctx.pos;
		Node* node = parse_top_level_statement(ctx);
		if (ctx.pos == pos)
		{
			diagnostics::error(ctx.context, ctx.current.range, "Parser failed to advance in parse_top_level_statement. Returning!");
			break;
		}
		ctx.ast.statements.push(node);
	}

	return ctx.error_count == 0;
}

fn void attach_attributes(ParseContext* ctx, Node* node, NodeArray attr)
{
	if (!attr) return;

	switch (node.kind)
	{
		case STRUCT_DECL:
			node.as(StructDecl).attributes = attr;
			break;
		case MODULE_DECL:
			node.as(ModuleDecl).attributes = attr;
			break;
		case IMPORT_DECL:
			node.as(ImportDecl).attributes = attr;
			break;
		case ENUM_DECL:
			node.as(EnumDecl).attributes = attr;
			break;
		default:
	}
}

fn Node* parse_top_level_statement(ParseContext* ctx)
{
	diagnostics::log_debug("parse_top_level_statement: %s", ctx.current.value);

	Node* node;
	NodeArray attrs;

	if (ctx.is(LBRACKET))
	{
		attrs = parse_attributes(ctx);
	}

	if (ctx.current.kind.is_primitive())
	{
		node = parse_global_decl(ctx);
		attach_attributes(ctx, node, attrs);
		return node;
	}

	switch (ctx.current.kind)
	{
		case MODULE:
			node = parse_module_decl(ctx);
		//case IMPORT:
		//	node = parse_import_decl(ctx);
		case FN:
			node = parse_fn_decl(ctx);
		case TYPEDEF:
			node = parse_typedef_decl(ctx);
		case STRUCT:
			node = parse_struct_decl(ctx);
		case ENUM:
			node = parse_enum_decl(ctx);
		case CONST:
			node = parse_global_decl(ctx);
		case EXTERN:
			if (ctx.peek(1).kind == FN)
			{
				node = parse_fn_decl(ctx);
			}
			else
			{
				node = parse_global_decl(ctx);
			}
		default:
			break;
	}

	attach_attributes(ctx, node, attrs);

	return node;
}
