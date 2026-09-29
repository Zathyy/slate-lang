module slate::lexer;

enum TokenKind : char
{
	<* Error *>
	ERROR,

	// Operators
	<* & *>
	AMP,

	<* | *>
	BIT_OR,

	<* ^ *>
	BIT_XOR,

	<* ~ *>
	BIT_NOT,

	<* ! *>
	BANG,

	<* + *>
	PLUS,

	<* - *>
	MINUS,

	<* * *>
	ASTERISK,

	<* / *>
	DIV,

	<* % *>
	MOD,

	<* ? *>
	QUESTION,

	<* ?? *>
	QUESTQUEST,

	<* ?: *>
	ELVIS,

	<* !! *>
	BANGBANG,

	<* ++ *>
	PLUSPLUS,

	<* -- *>
	MINUSMINUS,

	// Assignment
	<* = *>
	EQ,

	<* >>= *>
	RSHIFT_ASSIGN,

	<* <<= *>
	LSHIFT_ASSIGN,

	<* += *>
	PLUS_ASSIGN,

	<* -= *>
	MINUS_ASSIGN,

	<* *= *>
	MULT_ASSIGN,

	<* /= *>
	DIV_ASSIGN,

	<* %= *>
	MOD_ASSIGN,

	<* &= *>
	BIT_AND_ASSIGN,

	<* ^= *>
	BIT_XOR_ASSIGN,

	<* |= *>
	BIT_OR_ASSIGN,

	// Comparison
	<* < *>
	LESS,

	<* > *>
	GREATER,

	<* && *>
	AND,

	<* || *>
	OR,

	<* <= *>
	LESS_EQ,

	<* >= *>
	GREATER_EQ,

	<* == *>
	EQEQ,

	<* != *>
	NOT_EQUAL,

	// Punctuation
	<* ; *>
	EOS,

	<* : *>
	COLON,

	<* :: *>
	SCOPE,

	<* , *>
	COMMA,

	<* . *>
	DOT,

	<* .. *>
	DOTDOT,

	<* ... *>
	ELLIPSIS,

	// Structure
	<* { *>
	LBRACE,

	<* } *>
	RBRACE,

	<* [ *>
	LBRACKET,

	<* ] *>
	RBRACKET,

	<* ( *>
	LPAREN,

	<* ) *>
	RPAREN,

	<* -> *>
	ARROW,

	<* => *>
	IMPLIES,

	<* // *>
	LINE_COMMENT,

	<* /* *>
	BLOCK_COMMENT,

	// Literals (Identifiers and Strings)
 	<* STRING *>
	STRING_LITERAL,

	<* 'a' 'FO' 'BARS' '\u1232' *>
	CHAR_LITERAL,
	<* Base64 or Hex *>
	BYTES_LITERAL,

	<* 123 *>
	INT_LITERAL,

	<*  *>
	FLOAT_LITERAL,

	<* $$ident *>
	BUILTIN,

	<* foo *>
	IDENT,

	<* '@' *>
	AT,

	<* Base Types *>
	VOID_TYPE,
	BOOL_TYPE,
	U8_TYPE,
	F32_TYPE,
	F64_TYPE,
	I8_TYPE,
	I32_TYPE,
	I64_TYPE,
	I16_TYPE,
	U32_TYPE,
	U64_TYPE,
	U16_TYPE,
	USIZE_TYPE,
	TYPEID_TYPE,

	// Keywords
	ASSERT,
	ASM,
	BREAK,
	CASE,
	CONST,
	CONTINUE,
	CAST,
	DEFAULT,
	DEFER,
	DO,
	ELSE,
	ENUM,
	EXTERN,
	FALSE,
	FOR,
	FOREACH,
	FN,
	TLOCAL,
	IF,
	INLINE,
	IMPORT,
	MODULE,
	NULL,
	RETURN,
	STATIC,
	STRUCT,
	SWITCH,
	TRUE,
	TYPEDEF,
	UNION,
	VAR,
	WHILE,

	EOF
}

fn bool TokenKind.is_primitive(self)
{
	return self.ordinal >= TokenKind.VOID_TYPE.ordinal && self.ordinal <= TokenKind.TYPEID_TYPE.ordinal;
}
