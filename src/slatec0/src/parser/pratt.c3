module slate::parser;
import std::collections;
import slate::core;
import slate::lexer;

constdef Precedence : inline int
{
	NONE           = -1,
	LOWEST         =  0,
	ASSIGNMENT     =  10, // =, *=, /=, %=, +=, etc
	TERNARY        =  20, // ?:
	OR             =  30, // || |||
	AND            =  40, // && &&&
	RELATIONAL     =  50, // < > <= >= == !=
	ADDITIVE       =  60, // + - +++
	ORELSE         =  70, // ?: ??
	BIT            =  80, // ^ | &
	SHIFT          =  90, // << >>
	MULTIPLICATIVE =  100, // * / %
	UNARY          =  110, // ! - + ~ * & prefix ++/--
	CALL           =  120, // . () [] postfix ++ -- !! ! ~
	HIGHEST        =  130,
}

fn bool is_shift_op(ParseContext* ctx, TokenKind expected_kind) @private
{
    if (ctx.current.kind != expected_kind) return false;

    Token next = ctx.peek(1);
    if (next.kind != expected_kind) return false;

    // Ensure no whitespace between the two tokens (e.g. 'a < < b' vs 'a << b')
    return ctx.current.range.end == next.range.start;
}

<*
 @param [&inout] lbp : "How strongly the operator pulls on the expression to its left."
 @param [&inout] rbp : "How strongly it pulls on the expression to its right."
*>
fn void get_binding_power(ParseContext* ctx, TokenKind type, int* lbp, int* rbp)
{
	if ((type == TokenKind.LESS && is_shift_op(ctx, TokenKind.LESS)) ||
        (type == TokenKind.GREATER && is_shift_op(ctx, TokenKind.GREATER)))
    {
        *lbp = Precedence.SHIFT;
        *rbp = Precedence.SHIFT + 1;
        return;
    }

    if (type == TokenKind.LESS && is_generic_args_lookahead(ctx))
    {
        *lbp = Precedence.CALL;
        *rbp = Precedence.CALL + 1;
        return;
    }

	switch (type)
	{
		// Assignment (Right-associative)
		case EQ:
		case MULT_ASSIGN:
		case PLUS_ASSIGN:
		case MINUS_ASSIGN:
		case DIV_ASSIGN:
		case MOD_ASSIGN:
			*lbp = Precedence.ASSIGNMENT;
			*rbp = Precedence.ASSIGNMENT - 1;
			break;

		case QUESTION:
			*lbp = Precedence.TERNARY;
			*rbp = Precedence.TERNARY - 1;
			break;

		case OR:
			*lbp = Precedence.OR;
			*rbp = Precedence.OR + 1;
			break;

		case AND:
			*lbp = Precedence.AND;
			*rbp = Precedence.AND + 1;
			break;

		// RELATIONAL
		case EQEQ:
		case NOT_EQUAL:
		case GREATER:
		case GREATER_EQ:
		case LESS:
		case LESS_EQ:
			*lbp = Precedence.RELATIONAL;
			*rbp = Precedence.RELATIONAL + 1;
			break;

		// ADDITIVE
		case PLUS:
		case MINUS:
			*lbp = Precedence.ADDITIVE;
			*rbp = Precedence.ADDITIVE + 1;
			break;

		case QUESTQUEST:
		case ELVIS:
			*lbp = Precedence.ORELSE;
			*rbp = Precedence.ORELSE + 1;
			break;

		// Bit
		case BIT_OR:
		case BIT_XOR:
		case AMP:
			*lbp = Precedence.BIT;
			*rbp = Precedence.BIT + 1;
			break;

		// MULTIPLICATIVE
		case DIV:
		case MOD:
		case ASTERISK:
			*lbp = Precedence.MULTIPLICATIVE;
			*rbp = Precedence.MULTIPLICATIVE + 1;
			break;

		// Postfix / Access / Call
		case DOT:
		case SCOPE:
		case LPAREN:
		case LBRACE:
		case LBRACKET:
			*lbp = Precedence.CALL;
			*rbp = Precedence.CALL + 1; // TODO: CALL or None?
			break;
		case BANGBANG:
		case PLUSPLUS:
		case MINUSMINUS:
		case BANG:
			*lbp = Precedence.CALL;
			*rbp = Precedence.LOWEST; // Postfix has no RHS to pull
			break;

		default:
			*lbp = Precedence.NONE;
			*rbp = Precedence.NONE;
			break;
	}
}

<*
 parse expressions recursively with Pratt parsing
	using Binding power.
 @param min_bp : "Starting binding power"
*>
fn Node* parse_expr(ParseContext* ctx, Precedence min_bp = LOWEST)
{
	Node* left = parse_prefix_expr(ctx);

	while (true)
	{
		int lbp, rbp;
		get_binding_power(ctx, ctx.current.kind, &lbp, &rbp);

		diagnostics::log_debug("Current Token: %s, LBP: %d, MinBP: %d", ctx.current.kind, lbp, min_bp);

		if (lbp == Precedence.NONE || lbp < min_bp)
		{
			break;
		}

		left = parse_infix(ctx, left, (Precedence)rbp);
	}

	return left;
}

<*
 parse_prefix (Nud)
	Handles tokens that start an expression (e.g., -5, (expr), !true)
	It has no "left" side to worry about.
*>
fn Node* parse_prefix_expr(ParseContext* ctx)
{
	Token t = ctx.current;

	switch (t.kind)
	{
		case IDENT:
	    {
	        advance(ctx);
	        IdentExpr* id = ctx.ast.alloc_node(IdentExpr, t.range);
	        id.ident = ctx.ident(t);
	        return (Node*)id;
	    }
		case BUILTIN:
		{
			advance(ctx);
			if (ctx.current.kind != IDENT)
			{
				diagnostics::error(ctx.context, ctx.peek(1).range, "'$$' must be followed by a 'ident'");
				ctx.error_count++;
				advance(ctx);
				return null;
			}

			BuiltinExpr* builtin = ctx.ast.alloc_node(BuiltinExpr, { t.range.start, ctx.current.range.end, ctx.current.range.file_id });
			builtin.value = parse_ident(ctx);
			return builtin;
		}
		case CAST:
			return parse_cast_expr(ctx);
		case BANG:
		case MINUS:
		case BIT_NOT:
		case AMP:
		case AND:
		case ASTERISK:
		case PLUSPLUS:
		case MINUSMINUS:
			return parse_unary_expr(ctx);
		case STRING_LITERAL:
		case CHAR_LITERAL:
		case TRUE:
		case FALSE:
		case NULL:
		case FLOAT_LITERAL:
		case INT_LITERAL:
		case BYTES_LITERAL:
			return parse_literal_expr(ctx);
		default:
			diagnostics::error(ctx.context, ctx.current.range, "Expected expression, got: %s", ctx.current.kind.description);
			advance(ctx);
			return ctx.ast.error(ctx.current.range);
	}
}

<*
 parse_infix (Led)
 Handles tokens that connect expressions (e.g. 1 + 2, obj.prop, arr[0])
 It takes a pre-parsed "left" node and attaches a "right" side to it.
*>
fn Node* parse_infix(ParseContext* ctx, Node* left, Precedence rbp)
{
	Token t = ctx.current;

    // Handle '<<' shift operator
    if (t.kind == TokenKind.LESS && is_shift_op(ctx, TokenKind.LESS))
    {
        advance(ctx, 2);

        Node* right = parse_expr(ctx, rbp);

        BinaryExpr* bin = ctx.ast.alloc_node(BinaryExpr, t.range);
        bin.op = OperatorKind.OP_SHL;
        bin.left = left;
        bin.right = right;
        return (Node*)bin;
    }

    // Handle '>>' shift operator
    if (t.kind == TokenKind.GREATER && is_shift_op(ctx, TokenKind.GREATER))
    {
        advance(ctx, 2);

        Node* right = parse_expr(ctx, rbp);

        BinaryExpr* bin = ctx.ast.alloc_node(BinaryExpr, t.range);
        bin.op = OperatorKind.OP_SHR;
        bin.left = left;
        bin.right = right;
        return (Node*)bin;
    }

	switch (t.kind)
	{
		case PLUS:
		case PLUS_ASSIGN:
		case MINUS:
		case MINUS_ASSIGN:
		case ASTERISK:
		case MULT_ASSIGN:
		case DIV:
		case DIV_ASSIGN:
		case MOD:
		case MOD_ASSIGN:
		case EQ:
		case EQEQ:
		case GREATER:
		case GREATER_EQ:
		case LESS:
		case LESS_EQ:
		case AMP:
		case AND:
		case BIT_AND_ASSIGN:
		case NOT_EQUAL:
		case RSHIFT_ASSIGN:
		case LSHIFT_ASSIGN:
		case QUESTQUEST:
		case ELVIS:
			return parse_binary_expr(ctx, left, rbp);
		case DOT:
		case SCOPE:
			advance(ctx);
	        Node* right = parse_expr(ctx, HIGHEST); // HIGHEST bp to avoid consuming downstream infix operators.
	        AccessExpr* access = ctx.ast.alloc_node(AccessExpr, t.range);
			access.access_kind = t.kind == SCOPE ? STATIC : INSTANCE;
	        access.left = left;
	        access.right = right;
	        return access;
		case PLUSPLUS:
		case MINUSMINUS:
		case BANG:
		case BANGBANG:
			return parse_post_unary_expr(ctx, left, rbp);
		case LPAREN:
			return parse_call_expr(ctx, left);
		default:
			diagnostics::error(ctx.context, ctx.current.range, "Expected expression");
			advance(ctx);
			return ctx.ast.error(ctx.current.range);
	}
}

<*
 "Shortcut" for when a left node has already been parsed (like an identifier)
 and want to continue building an expression from that specific point without starting over
*>
fn Node* parse_expr_resuming_with_left(ParseContext* ctx, Node* left, Precedence min_bp)
{
	while (true)
	{
		int lbp, rbp;
		get_binding_power(ctx, ctx.current.kind, &lbp, &rbp);
		if (lbp < min_bp) break;

		left = parse_infix(ctx, left, (Precedence)rbp);
	}
	return left;
}

<*
 Parses only the leading prefix/atom expression and returns immediately
 without binding any trailing infix operators.
*>
fn Node* parse_prefix_expr_only(ParseContext* ctx)
{
	// Pass HIGHEST so the Pratt loop breaks immediately on any trailing infix token
	return parse_expr(ctx, Precedence.HIGHEST);
}

fn Node* parse_constant_expr(ParseContext* ctx)
{
	return parse_expr(ctx, ASSIGNMENT + 1);
}
