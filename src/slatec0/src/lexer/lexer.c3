module slate::lexer;

import slate::core;

import std::io;

import std::collections::list;

<*
 @param [&in] ctx : "main context"
*>
fn Lexer* create(CompilerContext* ctx, String buffer, bool emit_comments = false)
{
	Lexer* lexer = alloc::new(ctx.alloc, Lexer);

	lexer.context = ctx;
	lexer.tokens.init(ctx.alloc);
	lexer.buffer = buffer.copy(ctx.alloc);
	lexer.current = buffer.len > 0 ? buffer[0] : 0;
	lexer.emit_comments = emit_comments;

	return lexer;
}

struct Token
{
	TokenKind kind;
	String value;
	Range range;
}

struct Lexer
{
	CompilerContext* context;
	String buffer;
	List{Token} tokens;
	Location location;
	char current;
	int index;
	bool emit_comments;
}

fn bool Token.is_eof(&self) @inline => self.kind == EOF;

fn bool is_digit(char c) @inline => c.is_digit();
fn bool is_alpha(char c) @inline => c.is_alpha();
fn bool is_ident(char c) @inline => is_alpha(c) || is_digit(c) || c == '_';
fn bool is_hex(char c) @inline => ascii::is_xdigit(c);
fn bool Lexer.eof(&self) => self.current == 0;

fn char Lexer.peek(&self, sz ahead = 1) @inline
{
	if (self.index + ahead >= self.buffer.len) return 0;
	return self.buffer[self.index + ahead];
}

fn String Lexer.get_string(&self, int start, int len)
{
	return self.buffer[start:len];
}

fn void skip_whitespace(Lexer* self)
{
	while (self.current != 0 && self.current.is_space())
	{
		advance(self);
	}
}

fn Token lex_line_comment(Lexer* self)
{
	int start_index = self.index;
	advance(self, 2);
	while (self.current != 0 && self.current != '\n' && self.current != '\r')
    {
        advance(self);
    }

	return self.emit_range(LINE_COMMENT, start_index);
}

fn Token lex_block_comment(Lexer* self)
{
	int start_index = self.index;
	advance(self, 2); // Skip the initial '/*'
	int depth = 1;
	while (self.current != 0 && depth != 0)
	{
		if (self.current == '/' && self.peek(1) == '*')
		{
			advance(self, 2);
			depth++;
		}
		else if (self.current == '*' && self.peek(1) == '/')
		{
			advance(self, 2);
			depth--;
		}
		else
		{
			advance(self);
		}
	}

	if (depth > 0)
	{
		return self.emit_range(ERROR, start_index);
	}

	return self.emit_range(BLOCK_COMMENT, start_index);
}

fn Token lex_char(Lexer* self)
{
	int start_index = self.index;
	advance(self);

	while (self.current != 0)
	{
		char c = self.buffer[self.index];

		if (c == '\'')
		{
			advance(self);
			return self.emit_range(CHAR_LITERAL, start_index);
		}

		if (c == '\\')
		{
			char next = self.peek();
			if (next == 'x')
			{
			   	advance(self, 4);
			}
			else
			{
				advance(self, 2);
			}
			continue;
		}

		advance(self);
	}

	return self.emit_range(ERROR, start_index);
}

fn Token lex_string(Lexer* self)
{
	int start_index = self.index;
	advance(self);

	while (self.current != 0)
	{
		char c = self.current;

		if (c == '"')
		{
			advance(self);
			return self.emit_range(STRING_LITERAL, start_index);
		}

		if (c == '\\')
		{
			advance(self, 2);
			continue;
		}

		advance(self);
	}

	return self.emit_range(STRING_LITERAL, start_index);
}

fn Token lex_raw_string(Lexer* self)
{
	Location start = self.location;
	int start_index = self.index;

	// Count the number of opening backticks
	int delim_len = 0;
    while (self.current == '`')
    {
        delim_len++;
        advance(self);
    }

    // Scan until finding matching number of backticks
	while (self.current != 0)
	{
		if (self.current == '`')
		{
			int count = 0;
            while (self.current == '`')
            {
                count++;
                advance(self);
            }
            if (count == delim_len)
            {
				return {
					.kind = STRING_LITERAL,
					.value = self.get_string(start_index, self.index - start_index),
					.range = {
						.start = start,
						.end = self.location
					}
				};
			}
			continue;
		}
		advance(self);
	}

	return self.emit_range(ERROR, start_index);
}

fn TokenKind lookup_keyword(String text)
{
	switch (text)
	{
		// Top-Level Explicit Keywords
		case "const": return CONST;
		case "enum": return ENUM;
		case "fn": return FN;
		case "import": return IMPORT;
		case "module": return MODULE;
		case "typedef": return TYPEDEF;
		case "struct": return STRUCT;
		case "union": return UNION;
		// Explicit Keywords
		case "asm": return ASM;
		case "assert": return ASSERT;
		case "break": return BREAK;
		case "case": return CASE;
		case "continue": return CONTINUE;
		case "cast": return CAST;
		case "default": return DEFAULT;
		case "defer": return DEFER;
		case "do": return DO;
		case "else": return ELSE;
		case "false": return FALSE;
		case "for": return FOR;
		case "foreach": return FOREACH;
		case "if": return IF;
		case "null": return NULL;
		case "return": return RETURN;
		case "static": return STATIC;
		case "switch": return SWITCH;
		case "true": return TRUE;
		case "var": return VAR;
		case "while": return WHILE;
		case "extern": return EXTERN;
		case "inline": return INLINE;
		case "tlocal": return TLOCAL;
		// Base
		case "void": return VOID_TYPE;
		case "bool": return BOOL_TYPE;
		case "u8": return U8_TYPE;
		case "i8": return I8_TYPE;
		case "i16": return I16_TYPE;
		case "u16": return U16_TYPE;
		case "i32": return I32_TYPE;
		case "u32": return U32_TYPE;
		case "i64": return I64_TYPE;
		case "u64": return U64_TYPE;
		case "usize": return USIZE_TYPE;
		case "f32": return F32_TYPE;
		case "f64": return F64_TYPE;
		case "typeid": return TYPEID_TYPE;
		default: return IDENT;
	}
}

fn Token lex_identifier(Lexer* self)
{
	Location start = self.location;
	int start_index = self.index;
	char first = self.current;

	advance(self);
	while (self.current != 0 && is_ident(self.current))
	{
		advance(self);
	}

	int length = self.index - start_index;
	if (length <= 0)
	{
		diagnostics::error(self.context,
		{ start, self.location, self.context.current_source_file },
		"Length of identifier was less or eq to 0");
		return self.emit_range(ERROR, start_index);
	}

	String text = self.get_string(start_index, length);

	TokenKind kind = categorize_identifier(self, text);

	return self.emit_range(kind, start_index);
}

fn Token lex_number(Lexer* self)
{
	Location start = self.location;
	int start_index = self.index;

	// Hex: 0x
	if (self.current == '0' && (ascii::to_lower(self.peek()) == 'x'))
	{
		advance(self, 2);
		// Allow hex digits OR underscores
		while (self.current != 0 && (ascii::is_xdigit(self.current) || self.current == '_'))
		{
			advance(self);
		}

		if (self.current != 0 && self.current == '.' && self.peek() != '.') // && ascii::is_xdigit(self.peek_next()))
		{
			advance(self);
			while (self.current != 0 && (ascii::is_xdigit(self.current) || self.current == '_'))
			{
				advance(self);
			}
		}

		if (self.current != 0 && (self.current == 'p' || self.current == 'P'))
		{
			char next = self.peek();
			if (ascii::is_xdigit(next) || next == '-' || next == '+')
			{
				advance(self);
				if (next == '-' || next == '+') advance(self);
				while (!self.eof() && (ascii::is_xdigit(self.peek()) || self.peek() == '_'))
				{
					advance(self);
				}
			}
		}
	} // Binary: 0b
	else if (self.current == '0' && (ascii::to_lower(self.peek()) == 'b'))
	{
		advance(self, 2);
		while (self.current != 0 && (ascii::is_bdigit(self.current) || self.current == '_'))
		{
			advance(self);
		}
	} // Octal: 0o
	else if (self.current == '0' && (ascii::to_lower(self.peek()) == 'o'))
	{
		advance(self, 2);
		while (self.current != 0 && (ascii::is_odigit(self.current) || self.peek() == '_'))
		{
			advance(self);
		}
	}
	else
	{
		// Standard Decimals
		while (self.current != 0 && (ascii::is_digit(self.current) || self.current == '_'))
		{
			advance(self);
		}

		// Real/Float check
		if (self.current != 0 && self.current == '.' && self.peek() != '.') // && ascii::is_digit(self.peek_next()))
		{
			advance(self);
			while (self.current != 0 && (ascii::is_digit(self.current) || self.current == '_'))
			{
				advance(self);
			}
		}

		if (self.current != 0 && (self.current == 'e' || self.current == 'E'))
		{
			char next = self.peek();
			if (ascii::is_digit(next) || next == '-' || next == '+')
			{
				advance(self);
				if (next == '-' || next == '+') advance(self);
				while (self.current != 0 && (ascii::is_digit(self.current) || self.current == '_'))
				{
					advance(self);
				}
			}
		}
	}

	// Handle Suffixes (e.g., 1u, 1.0f, 0xFFu64)
	char c = (char)ascii::to_lower(self.current);
	if (c == 'u' || c == 'i' || c == 'f' || c == 'l')
	{
		advance(self);
		while (self.current != 0 && ascii::is_alnum(self.current))
		{
			advance(self);
		}
	}

	return self.emit_range(INT_LITERAL, start_index);
}

fn Token lex_hex_array(Lexer* self)
{
	Location start = self.location;
	int start_index = self.index;
	char start_quote = self.peek();
	advance(self, 2);

	int digit_count = 0;

	while (self.current != 0)
	{
		char c = self.current;

		if (c == start_quote)
		{
			advance(self);
			break;
		}

		if (c.is_space())
		{
			advance(self);
			continue;
		}

		if (is_hex(c))
		{
			advance(self);
			digit_count++;
			continue;
		}

		diagnostics::error(self.context, { start ,self.location_at(self.index), self.context.current_source_file }, "[Lexer]: Unexpected character '%c'", c);
		return {
			.kind = ERROR,
			.value = self.get_string(start_index, self.index - start_index),
			.range = {
				.start = start,
				.end = self.location
			}
		};
	}

	if (digit_count % 2 != 0)
	{
		diagnostics::error(self.context, {  }, "[Lexer]: The hexadecimal string is not an even length");
		return {
			.kind = ERROR,
			.value = self.get_string(start_index, self.index - start_index),
			.range = {
				.start = start,
				.end = self.location
			}
		};
	}

	return self.emit_range(BYTES_LITERAL, start_index);
}

fn void advance(Lexer* self, int len = 1)
{
	for (int i = 0; i < len; i++)
	{
		if (self.index < self.buffer.len)
		{
			char c = self.buffer[self.index];
			if (c == '\n')
			{
				self.location.line++;
				self.location.column = 0;
			}
			else
			{
				self.location.column++;
			}
			self.index++;
		}
	}
	self.current = (self.index < self.buffer.len) ? self.buffer[self.index] : 0;
}

fn Token Lexer.emit(&self, TokenKind kind, String value)
{
	Location start = self.location;

	advance(self, value.len);

	return {
		.kind = kind,
		.range = {
			.start = start,
			.end = self.location
		},
		.value = value
	};
}

fn Location Lexer.location_at(Lexer* self, int target_index)
{
	int line;
	int column;

	// Scan the buffer from the beginning up to the target index
	for (int i = 0; i < target_index; i++)
	{
		if (self.buffer[i] == '\n')
		{
			line++;
			column = 0; // Reset column on new line
		}
		else
		{
			column++;
		}
	}

	return { .line = line, .column = column };
}

fn Token Lexer.emit_range(Lexer* self, TokenKind kind, int start_index)
{
	return {
		.kind = kind,
		.value = self.get_string(start_index, self.index - start_index),
		.range = { .start = self.location_at(start_index), .end = self.location }
	};
}

fn void tokenize(Lexer* lexer)
{
	while (true)
	{
		Token t = next(lexer);
		if (!lexer.emit_comments && (t.kind == LINE_COMMENT || t.kind == BLOCK_COMMENT))
		{
			continue;
		}
		diagnostics::log_debug("Added token: %s - %s", t.kind.description, t.value);
		t.range.file_id = lexer.context.current_source_file;
		lexer.tokens.push(t);
		if (t.kind == EOF) break;
	}
}

fn Token next(Lexer* lexer)
{
	skip_whitespace(lexer);

	switch (lexer.current)
	{
		case 0: break;
		case '=':
			switch (lexer.peek(1))
			{
				case '=': return lexer.emit(EQEQ, "==");
				case '>': return lexer.emit(IMPLIES, "=>");
				default:
			}
			return lexer.emit(EQ, "=");
		case '|':
			switch (lexer.peek(1))
			{
				case '|':
					return lexer.emit(OR, "||");
				case '=': return lexer.emit(BIT_OR_ASSIGN, "|=");
			}
			return lexer.emit(BIT_OR, "|");
		case '!':
			switch (lexer.peek())
			{
				case '!': return lexer.emit(BANGBANG, "!!");
				case '=': return lexer.emit(NOT_EQUAL, "!=");
			}
			return lexer.emit(BANG, "!");
		case ':':
			if (lexer.peek() == ':')
			{
				return lexer.emit(SCOPE, "::");
			}
			return lexer.emit(COLON, ":");
		case '[':
			return lexer.emit(LBRACKET, "[");
		case ']':
			return lexer.emit(RBRACKET, "]");
		case '>':
			return lexer.emit(GREATER, ">");
		case '<':
			return lexer.emit(LESS, "<");
		case '&':
			switch (lexer.peek())
			{
				case '&':
				{
					return lexer.emit(AND, "&&");
				}
				case '=': return lexer.emit(BIT_AND_ASSIGN, "&=");
			}
			return lexer.emit(AMP, "&");
		case '*':
			switch (lexer.peek())
			{
				case '=': return lexer.emit(MULT_ASSIGN, "*=");
			}
			return lexer.emit(ASTERISK, "*");
		case '?':
			switch (lexer.peek())
			{
				case '?':
					return lexer.emit(QUESTQUEST, "??");
				case ':': return lexer.emit(ELVIS, "?:");
			}
			return lexer.emit(QUESTION, "?");
		case '.':
			if (lexer.peek() == '.')
			{
				if (lexer.peek(2) == '.')
				{
					return lexer.emit(ELLIPSIS, "...");
				}

				return lexer.emit(DOTDOT, "..");
			}
			return lexer.emit(DOT, ".");
		case '%':
			if (lexer.peek() == '=')
			{
				return lexer.emit(MOD_ASSIGN, "%=");
			}
			return lexer.emit(MOD, "%");
		case '$':
			if (lexer.peek() == '$')
			{
				return lexer.emit(BUILTIN, "$$");
			}
		case '^':
			if (lexer.peek() == '=')
			{
				return lexer.emit(BIT_XOR_ASSIGN, "^=");
			}
			return lexer.emit(BIT_XOR, "^");
		case '+':
			switch (lexer.peek())
			{
				case '+':
				{
					return lexer.emit(PLUSPLUS, "++");
				}
				case '=':
					return lexer.emit(PLUS_ASSIGN, "+=");
			}
			return lexer.emit(PLUS, "+");
		case '-':
			switch (lexer.peek())
			{
				case '-': return lexer.emit(MINUSMINUS, "--");
				case '=': return lexer.emit(MINUS_ASSIGN, "-=");
				case '>': return lexer.emit(ARROW, "->");
			}
			return lexer.emit(MINUS, "-");
		case '~': return lexer.emit(BIT_NOT, "~");
		case '(': return lexer.emit(LPAREN, "(");
		case ')': return lexer.emit(RPAREN, ")");
		case '{': return lexer.emit(LBRACE, "{");
		case '}': return lexer.emit(RBRACE, "}");
		case ';': return lexer.emit(EOS, ";");
		case ',': return lexer.emit(COMMA, ",");
		case '/':
			switch (lexer.peek(1))
			{
				case '/': return lex_line_comment(lexer);
				case '*': return lex_block_comment(lexer);
				case '=': return lexer.emit(DIV_ASSIGN, "/=");
				default: break;
			}
			return lexer.emit(DIV, "/");
		case '\'':
			return lex_char(lexer);
		case '"':
			return lex_string(lexer);
		case '`':
			return lex_raw_string(lexer);
		case 'x':
			if (lexer.peek(1) == '"' || lexer.peek(1) == '\'' || lexer.peek(1) == '`')
			{
				return lex_hex_array(lexer);
			}
			nextcase;
		case '@':
		case '#':
			return lex_identifier(lexer);
		default:
			if (is_digit(lexer.current)) return lex_number(lexer);
			if (is_ident(lexer.current)) return lex_identifier(lexer);

			if (lexer.current != 0)
			{
				diagnostics::error(lexer.context, { lexer.location, lexer.location, lexer.context.current_source_file },
					"Unexpected character: %c", lexer.current);

				Token err = lexer.emit(ERROR, "");
				advance(lexer);
				return err;
			}
			break;
	}

	return {
		.kind = EOF,
		.range = {
			.start = lexer.location,
			.end = lexer.location
		},
		.value = "<EOF>"
	};
}

fn TokenKind categorize_identifier(Lexer* self, String text)
{
	if (text.len == 0) return ERROR;

	char prefix = text[0];
	String base;
	bool has_prefix = false;

	if (prefix == '@' && text.len == 1)
	{
		return AT;
	}

	if (prefix == '@' || prefix == '$' || prefix == '#')
	{
		base = text[1:text.len - 1];
		has_prefix = true;
	}
	else
	{
		base = text;
		TokenKind kind = lookup_keyword(base);
		if (kind != IDENT) return kind;
	}

	while (base.len > 0 && base[0] == '_')
	{
		base = base[1..];
	}

	return IDENT;
}

struct KindString @private
{
	TokenKind kind;
	String value;
}

fn void test_lexer() @test
{
	KindString[*] expected = {
		{ MODULE, "module" },
		{ IDENT, "foo" },
		{ EOS, ";" },
		{ FN, "fn" },
		{ VOID_TYPE, "void" },
		{ IDENT, "bar" },
		{ LPAREN, "(" },
		{ RPAREN, ")" },
		{ LBRACE, "{" },
		{ RBRACE, "}" },
		{ EOF, "<EOF>" }
	};

	String src  = `
		module foo;

		fn void bar()
		{

		}
	`;
	CompilerContext* context = context::create();
	defer context::free(context);
	Lexer* lexer = create(context, src);
	SourceFile* sf = source_file::create(context, lexer, "test");

	tokenize(lexer);

	foreach (t : lexer.tokens)
	{
		diagnostics::log_error("Token: %s - %s", t.kind.description, t.value);
	}

	test::eq(lexer.tokens.len(), expected.len);

	foreach (i, v : lexer.tokens)
	{
		test::eq(expected[i].kind, v.kind);
		test::eq(expected[i].value, v.value);
	}
}

fn void test_idents() @test
{
	KindString[*] expected = {
		{ IDENT, "foo" },
		{ IDENT, "FOO" },
		{ IDENT, "_foo" },
		{ EOF, "<EOF>" },
	};

	String src  = `
		foo Foo _foo
	`;
	CompilerContext* context = context::create();
	defer context::free(context);
	Lexer* lexer = create(context, src);
	SourceFile* sf = source_file::create(context, lexer, "test");

	tokenize(lexer);
	foreach (t : lexer.tokens)
	{
		diagnostics::log_error("Token: %s - %s", t.kind.description, t.value);
	}
	test::eq(lexer.tokens.len(), expected.len);

	foreach (i, v : lexer.tokens)
	{
		test::eq(expected[i].kind, v.kind);
		test::eq(expected[i].value, v.value);
	}
}
