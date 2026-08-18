module slate::parser;

import slate::core;
import slate::lexer;

fn bool is_type_start_lookahead(ParseContext* ctx) @private
{
    int cursor = 0;

    while (ctx.peek(cursor).kind == TokenKind.IDENT)
    {
        cursor++;
        if (ctx.peek(cursor).kind == TokenKind.SCOPE) // '::'
        {
            cursor++;
        }
        else
        {
            break;
        }
    }

    TokenKind follower = ctx.peek(cursor).kind;

    if (follower == TokenKind.ASTERISK) return true;  // foo::bar*
    if (follower == TokenKind.LBRACKET) return true;  // foo::bar[] or foo::bar[N]

    if (follower == TokenKind.LESS)
    {
        // Use lookahead to ensure '<' is a generic type list, not a relational operator
        return is_generic_args_lookahead_at(ctx, cursor);
    }

    return false;
}

fn bool is_type_decl_lookahead(ParseContext* ctx)
{
    int offset = 0;

    // Must start with an identifier or primitive type
    if (ctx.peek(offset).kind != TokenKind.IDENT && !ctx.peek(offset).kind.is_primitive())
    {
        return false;
    }

    // Consume qualified path: IDENT ( "::" IDENT )*
    while (ctx.peek(offset).kind == TokenKind.IDENT)
    {
        offset++;
        if (ctx.peek(offset).kind == TokenKind.SCOPE)
        {
            offset++;
        }
        else
        {
            break;
        }
    }

    // Balance generic parameters: < ... > (handles nested generics like Map<K, List<V>>)
    if (ctx.peek(offset).kind == TokenKind.LESS)
    {
        int depth = 0;
        while (ctx.peek(offset).kind != TokenKind.EOF)
        {
            TokenKind k = ctx.peek(offset).kind;
            if (k == TokenKind.LESS)
            {
                depth++;
            }
            else if (k == TokenKind.GREATER)
            {
                depth--;
                if (depth == 0)
                {
                    offset++;
                    break;
                }
            }
            else if (k == TokenKind.EOS || k == TokenKind.RBRACE)
            {
                // Safety bailout: statement or block ended before closing '>'
                return false;
            }
            offset++;
        }
    }

    // Balance slice / array bracket modifiers: [] or [N]
    while (ctx.peek(offset).kind == TokenKind.LBRACKET)
    {
        int depth = 0;
        while (ctx.peek(offset).kind != TokenKind.EOF)
        {
            TokenKind k = ctx.peek(offset).kind;
            if (k == TokenKind.LBRACKET)
            {
                depth++;
            }
            else if (k == TokenKind.RBRACKET)
            {
                depth--;
                if (depth == 0)
                {
                    offset++;
                    break;
                }
            }
            else if (k == TokenKind.EOS || k == TokenKind.RBRACE)
            {
                return false;
            }
            offset++;
        }
    }

    // Skip pointer stars (*) and const qualifiers
    while (ctx.peek(offset).kind == TokenKind.ASTERISK || ctx.peek(offset).kind == TokenKind.CONST)
    {
        offset++;
    }

    // Verdict: If followed by an identifier, this is a variable declaration (e.g. "std::List<i32>* x")
    return ctx.peek(offset).kind == TokenKind.IDENT;
}

fn bool is_generic_args_lookahead_at(ParseContext* ctx, int start_offset = 0)
{
    // Must start with '<'
    if (ctx.peek(start_offset).kind != TokenKind.LESS) return false;

    // Shift operator '<<' is NEVER a generic argument list
    if (ctx.peek(start_offset + 1).kind == TokenKind.LESS) return false;

    int idx = start_offset + 1;
    int depth = 1;

    // Scan forward until matching '>'
    while (depth > 0)
    {
        Token t = ctx.peek(idx);

        // Statements/delimiters that CANNOT appear inside a type argument list
        if (t.kind == TokenKind.EOS || t.kind == TokenKind.EOF ||
            t.kind == TokenKind.LBRACE || t.kind == TokenKind.RBRACE)
        {
            return false; // It's a relational expression 'a < b;'
        }

        if (t.kind == TokenKind.LESS) depth++;
        if (t.kind == TokenKind.GREATER) depth--;

        idx++;
    }

    // After the closing '>', check what follows
    Token trailing = ctx.peek(idx);

    // Generic types are followed by postfix operators (*, []), identifier (var decl), or call/init args
    return trailing.kind == TokenKind.LPAREN   ||
           trailing.kind == TokenKind.LBRACE   ||
           trailing.kind == TokenKind.DOT      ||
           trailing.kind == TokenKind.SCOPE    ||
           trailing.kind == TokenKind.ASTERISK ||
           trailing.kind == TokenKind.LBRACKET ||
           trailing.kind == TokenKind.IDENT;
}

fn bool is_generic_args_lookahead(ParseContext* ctx)
{
    return is_generic_args_lookahead_at(ctx, 0);
}

fn bool is_assignment_op(OperatorKind op)
{
    switch (op)
    {
        case OP_ELVIS:
        case OP_ASSIGN:
        case OP_ADD_ASSIGN:
        case OP_BIT_AND_ASSIGN:
        case OP_BIT_OR_ASSIGN:
        case OP_BIT_XOR_ASSIGN:
        case OP_DIV_ASSIGN:
        case OP_MOD_ASSIGN:
        case OP_MULT_ASSIGN:
        case OP_SHR_ASSIGN:
        case OP_SHL_ASSIGN:
        case OP_SUB_ASSIGN:
            return true;
        default:
            return false;
    }
}
