#include "lexer.h"

/**
 * Look ahead to see if 'e', 'E', 'p', or 'P' is followed by a sign or a digit
 */
static bool has_exponent(const Lexer& self)
{
    const u8 next_c = lexer::peek(self, 1);
    const u8 next_next_c = lexer::peek(self, 2);
    if (next_c == '+' || next_c == '-')
    {
        return is_digit(next_next_c);
    }
    return is_digit(next_c);
}

/**
 *  // skip 'e', 'E', 'p', or 'P'
 */
static void scan_exponent(Lexer& self)
{
    lexer::advance(self);
    if (self.current == '+' || self.current == '-')
    {
        lexer::advance(self);
    }
    while (self.current != 0 && (is_digit(self.current) || self.current == '_'))
    {
        lexer::advance(self);
    }
}

/**
 * If the number is followed immediately by alphabetical characters,
 * it's a type suffix (e.g., 100u, 3.14f32).
 */
static TokenType scan_number_suffix(Lexer& self, const TokenType kind)
{
    if (is_alpha(self.current))
    {
        while (is_alnum(self.current))
        {
            lexer::advance(self);
        }
    }
    return kind;
}

Token lexer::lex_ident(Lexer& self)
{
    Location start = self.location;
    usize start_index = self.index;
    u8 first = self.current;

    advance(self);
    while (self.current != 0 && is_ident(self.current))
    {
        advance(self);
    }

    usize length = self.index - start_index;
    if (length <= 0)
    {
        const Range range = { .start = start, .end = self.location };
        diag_error(range, "Length of identifier was less or eq to 0");
        return emit(self, TokenType::Error, "");
    }

    const String text = get_string(self, start_index, length);
    const TokenType type = lookup_keyword(self, text);
    return emit_range(self, type, start_index);
}

Token lexer::lex_number(Lexer& self)
{
    usize start_index = self.index;
    TokenType kind = TokenType::IntLiteral;

    // Hex: 0x
    if (self.current == '0' && (ascii_to_lower(peek(self, 1)) == 'x'))
    {
        kind = TokenType::IntLiteral; // Or TokenType::IntHexLiteral if you split them
        advance(self, 2);
        // Allow hex digits OR underscores
        while (self.current != 0 && (is_xdigit(self.current) || self.current == '_'))
        {
            advance(self);
        }

        if (self.current == '.' && peek(self, 1) != '.')
        {
            kind = TokenType::FloatLiteral; // Or FloatHexLiteral
            advance(self);
            while (self.current != 0 && (is_xdigit(self.current) || self.current == '_'))
            {
                advance(self);
            }
        }

        // '0x1p3' is a float even without a '.': the exponent makes it one.
        if ((self.current == 'p' || self.current == 'P') && has_exponent(self))
        {
            kind = TokenType::FloatLiteral;
            scan_exponent(self);
        }
    }
    // Binary: 0b
    else if (self.current == '0' && (ascii_to_lower(peek(self, 1)) == 'b'))
    {
        kind = TokenType::IntLiteral;
        advance(self, 2);
        while (self.current != 0 && (is_bdigit(self.current) || self.current == '_'))
        {
            advance(self);
        }
    }
    // Octal: 0o
    else if (self.current == '0' && (ascii_to_lower(peek(self, 1)) == 'o'))
    {
        kind = TokenType::IntLiteral;
        advance(self, 2);
        while (self.current != 0 && (is_odigit(self.current) || self.current == '_'))
        {
            advance(self);
        }
    }
    else
    {
        kind = TokenType::IntLiteral;

        // Standard Decimals
        while (self.current != 0 && (is_digit(self.current) || self.current == '_'))
        {
            advance(self);
        }

        // Real/Float check - '1..2' is a range, so a second '.' ends the number.
        if (self.current == '.' && peek(self, 1) != '.')
        {
            kind = TokenType::FloatLiteral;
            advance(self);
            while (self.current != 0 && (is_digit(self.current) || self.current == '_'))
            {
                advance(self);
            }
        }

        if ((self.current == 'e' || self.current == 'E') && has_exponent(self))
        {
            kind = TokenType::FloatLiteral;
            scan_exponent(self);
        }
    }

    kind = scan_number_suffix(self, kind);

    return emit_range(self, kind, start_index);
}

Token lexer::lex_string(Lexer& self)
{
    const u32 start_index = self.index;
    advance(self);

    while (self.current != 0)
    {
        const u8 c = self.current;

        if (c == '"')
        {
            advance(self);
            return emit_range(self, TokenType::StringLiteral, start_index);
        }

        if (c == '\\')
        {
            advance(self, 2);
            continue;
        }

        advance(self);
    }

    return emit_range(self, TokenType::StringLiteral, start_index);
}

Token lexer::lex_raw_string(Lexer& self)
{
    Location start = self.location;
    u32 start_index = self.index;

    // Count the number of opening backticks
    i32 delim_len = 0;
    while (self.current == '`')
    {
        delim_len++;
        advance(self);
    }

    // Scan until matching number of backticks is found
    while (self.current != 0)
    {
        if (self.current == '`')
        {
            i32 count = 0;
            while (self.current == '`')
            {
                count++;
                advance(self);
            }

            if (count == delim_len)
            {
                return {
                    .type = TokenType::StringLiteral,
                    .value = get_string(self, start_index, self.index - start_index),
                    .range = { .start = start, .end = self.location }
                };
            }

            continue;
        }

        advance(self);
    }

    return emit_range(self, TokenType::Error, start_index);
}

Token lexer::next(Lexer& self)
{
    skip_whitespace(self);

    self.start_location = self.location;

    switch (self.current)
    {
    case 0: break;
    case '=':
        switch (peek(self, 1))
        {
        case '=': return emit(self, TokenType::EqEq, "==");
        case '>': return emit(self, TokenType::Implies, "=>");
        default: break;
        }
        return emit(self, TokenType::Eq, "=");
    case '!':
        switch (peek(self, 1))
        {
        case '!': return emit(self, TokenType::BangBang, "!!");
        case '=': return emit(self, TokenType::NotEqual, "!=");
        default: break;
        }
        return emit(self, TokenType::Bang, "!");
    case ':':
        if (peek(self, 1) == ':')
        {
            return emit(self, TokenType::Scope, "::");
        }
        return emit(self, TokenType::Colon, ":");
    case '[':
        return emit(self, TokenType::LBracket, "[");
    case ']':
        return emit(self, TokenType::RBracket, "]");
    case '>':
        if (peek(self, 1) == '=')
        {
            return emit(self, TokenType::GreaterEq, ">=");
        }
        return emit(self, TokenType::Greater, ">");
    case '<':
        if (peek(self, 1) == '=')
        {
            return emit(self, TokenType::LessEq, "<=");
        }
        return emit(self, TokenType::Less, "<");
    case '&':
        switch (peek(self, 1))
        {
            case '&': return emit(self, TokenType::And, "&&");
            default: break;
        }
        return emit(self, TokenType::Amp, "&");
    case '*':
        if (peek(self, 1) == '=')
        {
            return emit(self, TokenType::MultiplyAssign, "*=");
        }
        return emit(self, TokenType::Asterisk, "*");
    case '?':
        switch (peek(self, 1))
        {
            case '?': return emit(self, TokenType::QuestQuest, "??");
            case ':': return emit(self, TokenType::Elvis, "?:");
            default: break;
        }
        return emit(self, TokenType::Question, "?");
    case '.':
        if (peek(self, 1) == '.')
        {
            if (peek(self, 2) == '.')
            {
                return emit(self, TokenType::Ellipsis, "...");
            }

            return emit(self, TokenType::DotDot, "..");
        }
        return emit(self, TokenType::Dot, ".");
    case '%':
        if (peek(self, 1) == '=')
        {
            return emit(self, TokenType::ModAssign, "%=");
        }
        return emit(self, TokenType::Mod, "%");
    case '^':
        if (peek(self, 1) == '=')
        {
            return emit(self, TokenType::BitXorAssign, "^=");
        }
        return emit(self, TokenType::BitXor, "^");
    case '+':
        switch (peek(self, 1))
        {
        case '+': return emit(self, TokenType::PlusPlus, "++");
        case '=': return emit(self, TokenType::PlusAssign, "+=");
        default: break;
        }
        return emit(self, TokenType::Plus, "+");
    case '-':
        switch (peek(self, 1))
        {
        case '-': return emit(self, TokenType::MinusMinus, "--");
        case '=': return emit(self, TokenType::MinusAssign, "-=");
        case '>': return emit(self, TokenType::Arrow, "->");
        default: break;
        }
        return emit(self, TokenType::Minus, "-");
    case '~':
        return emit(self, TokenType::BitNot, "~");
    case '(':
        return emit(self, TokenType::LParen, "(");
    case ')':
        return emit(self, TokenType::RParen, ")");
    case '{':
        return emit(self, TokenType::LBrace, "{");
    case '}':
        return emit(self, TokenType::RBrace, "}");
    case ';':
        return emit(self, TokenType::Eos, ";");
    case ',':
        return emit(self, TokenType::Comma, ",");
    case '/':
        switch (peek(self, 1))
        {
        case '/':
            skip_line_comment(self);
            return next(self);
        case '*':
            skip_block_comment(self);
            return next(self);
        case '=': return emit(self, TokenType::DivAssign, "/=");
        default: break;
        }
        return emit(self, TokenType::Div, "/");
    case '$':
        if (peek(self, 1) == '$')
        {
            return emit(self, TokenType::Builtin, "$$");
        }
    case '"':
        return lex_string(self);
    case '`':
        return lex_raw_string(self);
    default:
        if (is_digit(self.current))
            return lex_number(self);
        if (is_ident(self.current))
            return lex_ident(self);
        if (self.current != 0)
        {
            const Range range = { .start = self.location, .end = self.location, .file_id = self.file_id };
            diag_error(range, "Unexpected character %s", self.current);
            Token err = emit(self, TokenType::Error, "");
            advance(self, 1);
            return err;
        }
        break;
    }

    return {
        .type = TokenType::Eof,
        .value = "<EOF>",
        .range = { .start = self.location, .end = self.location }
    };
}

TokenType lexer::lookup_keyword(Lexer& self, const String text)
{
#define KEYWORD(str, type) if (text == str) return TokenType::type;
    KEYWORD("assert",   Assert)
    KEYWORD("case",     Case)
    KEYWORD("cast",     Cast)
    KEYWORD("const",    Const)
    KEYWORD("defer",    Defer)
    KEYWORD("else",     Else)
    KEYWORD("enum",     Enum)
    KEYWORD("extern",   Extern)
    KEYWORD("false",    False)
    KEYWORD("fn",       Fn)
    KEYWORD("for",      For)
    KEYWORD("foreach",  Foreach)
    KEYWORD("if",       If)
    KEYWORD("import",   Import)
    KEYWORD("inline",   Inline)
    KEYWORD("module",   Module)
    KEYWORD("null",     Null)
    KEYWORD("return",   Return)
    KEYWORD("static",   Static)
    KEYWORD("struct",   Struct)
    KEYWORD("switch",   Switch)
    KEYWORD("true",     True)
    KEYWORD("typedef",  Typedef)
    KEYWORD("var",      Var)
    KEYWORD("void",     VOID)
    KEYWORD("bool",     BOOL)
    KEYWORD("u8",       U8)
    KEYWORD("u16",      U16)
    KEYWORD("u32",      U32)
    KEYWORD("u64",      U64)
    KEYWORD("i8",       I8)
    KEYWORD("i16",      I16)
    KEYWORD("i32",      I32)
    KEYWORD("i64",      I64)
    KEYWORD("f32",      F32)
    KEYWORD("f64",      F64)
    KEYWORD("usize",    Usize)
    KEYWORD("typeid",   Typeid)
#undef KEYWORD

    return TokenType::Ident;
}

