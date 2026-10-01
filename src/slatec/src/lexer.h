#pragma once

#include "build_context.h"
#include "common/collections/list.h"
#include "common/common.h"
#include "common/diagnostics.h"
#include "common/primitives.h"
#include "common/string.h"

inline bool is_lower(const u8 c)
{
    return c >= 'a' && c <= 'z';
}

inline bool is_digit(const u8 c)
{
    return c >= '0' && c <= '9';
}

inline bool is_alpha(const u8 c)
{
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

inline bool is_alnum(const u8 c)
{
    return is_alpha(c) || is_digit(c);
}

inline bool is_space(const u8 c)
{
    return c == ' ' || c == '\t' || (c >= 9 && c <= 13);
}

inline bool is_ident(const u8 c)
{
    return is_alpha(c) || is_digit(c) || c == '_';
}

inline u8 ascii_to_lower(const u8 c) {
    return (c >= 'A' && c <= 'Z') ? (c + 32) : c;
}

inline bool is_xdigit(const u8 c) {
    return is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

inline bool is_odigit(const u8 c) {
    return c >= '0' && c <= '7';
}

inline bool is_bdigit(const u8 c) {
    return c == '0' || c == '1';
}

enum class TokenType : u8
{
    Error,
    Amp,          // &
    BitOr,        // |
    BitXor,       // ^
    BitNot,       // ~
    Bang,         // !
    Plus,         // +
    Minus,        // -
    Asterisk,     // *
    Div,          // /
    Mod,          // %
    Question,     // ?
    QuestQuest,   // ??
    Elvis,        // ?:
    BangBang,     // !!
    PlusPlus,     // ++
    MinusMinus,   // --

    Eq,           // =
    RShiftAssign, // >=
    LShiftAssign, // <=
    PlusAssign,   // +=
    MinusAssign,  // -=
    MultiplyAssign, // *=
    DivAssign,    // /=
    ModAssign,    // %=
    BitAndAssign,
    BitXorAssign,
    BirOrAssign,

    Less,
    Greater,
    And,
    Or,
    LessEq,
    GreaterEq,
    EqEq,
    NotEqual,

    // Punctuation
    Eos,
    Colon,
    Scope,
    Comma,
    Dot,
    DotDot,
    Ellipsis,

    // Structure
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    LParen,
    RParen,
    Arrow,   // ->
    Implies, // =>

    // Literals (Identifiers and Strings)
    StringLiteral,
    CharLiteral,
    BytesLiteral,
    IntLiteral,
    FloatLiteral,
    Builtin,
    Ident,
    At,

    VOID,
    BOOL,
    U8,
    F32,
    F64,
    I8,
    I32,
    I64,
    I16,
    U32,
    U64,
    U16,
    Usize,
    Typeid,

    // Keywords
    Assert,
    Case,
    Const,
    Cast,
    Defer,
    Else,
    Enum,
    Extern,
    False,
    For,
    Foreach,
    Fn,
    TLocal,
    If,
    Inline,
    Import,
    Module,
    Null,
    Return,
    Static,
    Struct,
    Switch,
    True,
    Typedef,
    Var,

    Eof
};

struct Token;

struct Lexer
{
    String buffer{};
    List<Token> tokens{};
    Location start_location{};
    Location location{};
    u8 current{};
    u32 index{};
    FileID file_id{};
};

struct Token
{
    TokenType type{};
    String value{};
    Range range{};
};

namespace lexer
{
    inline void init(Lexer& self, Arena& arena, const SourceFile& sf)
    {
        list::init(self.tokens, &arena);
        self.buffer = sf.content;
        self.current = self.buffer.len > 0 ? self.buffer[0] : 0;
        self.index = 0;
        self.location = {};
        self.file_id = sf.file_id;
    }

    inline u8 peek(const Lexer& self, const size ahead = 1)
    {
        if (self.index + ahead >= self.buffer.len) return 0;
        return self.buffer[self.index + ahead];
    }

    inline void advance(Lexer& self, size len = 1)
    {
        for (i32 i = 0; i < len; i++)
        {
            if (self.index < self.buffer.len)
            {
                u8 c = self.buffer[self.index];
                if (c == '\n')
                {
                    self.location.line++;
                    self.location.column = 0;
                }
                else
                {
                    self.location.column++;
                }
                self.index += 1;
            }
        }

        self.current = (self.index < self.buffer.len) ? self.buffer[self.index] : 0;
    }

    inline void skip_whitespace(Lexer& self)
    {
        while (self.current != 0 && is_space(self.current))
        {
            advance(self);
        }
    }

    inline void skip_line_comment(Lexer& self)
    {
        usize start = self.index;
        advance(self, 2);
        while (self.current != 0 && self.current != '\n' && self.current != '\r')
        {
            advance(self);
        }
    }

    inline void skip_block_comment(Lexer& self)
    {
        advance(self, 2); // skip '/*'
        int depth = 1;
        while (self.current != 0 && depth != 0)
        {
            if (self.current == '/' && peek(self, 1) == '*')
            {
                advance(self, 2);
                depth++;
            }
            else if (self.current == '*' && peek(self, 1) == '/')
            {
                advance(self, 2);
                depth--;
            }
            else
            {
                advance(self);
            }
        }

        // TODO: Warn/Error if depth is > 0?
    }

    inline String get_string(const Lexer& self, const usize start, const usize end)
    {
        return string::substring(self.buffer, start, end);
    }

    inline Token emit_range(const Lexer& self, const TokenType type, const usize start)
    {
        return {
            .type = type,
            .value = get_string(self, start, self.index - start),
            .range = {.start = self.start_location, .end = self.location}
        };
    }

    inline Token emit(Lexer& self, const TokenType type, const String value)
    {
        const Location start = self.location;

        advance(self, value.len);

        return {
            .type = type,
            .value = value,
            .range = {.start = start, .end = self.location}
        };
    }

    TokenType lookup_keyword(Lexer& self, String text);

    Token lex_ident(Lexer& self);

    Token lex_number(Lexer& self);

    Token lex_string(Lexer& self);

    Token lex_raw_string(Lexer& self);

    Token next(Lexer& self);

    inline void tokenize(Lexer& self)
    {
        while (true)
        {
            Token t = next(self);
            t.range.file_id = self.file_id;
            list::push(self.tokens, t);
            if (t.type == TokenType::Eof) break;
        }
    }

}