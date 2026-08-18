module slate::core;
import slate::lexer;

faultdef NOT_FOUND;

enum ResolveStatus : char
{
	UNRESOLVED,
	RESOLVING,
	RESOLVED
}

enum OperatorKind
{
	OP_ERROR,
	OP_MULT,
	OP_SUB,
	OP_ADD,
	OP_DIV,
	OP_MOD,
	OP_SHR,
	OP_SHL,
	OP_BIT_OR,
	OP_BIT_XOR,
	OP_BIT_AND,
	OP_AND,
	OP_OR,
	OP_ELSE,
	OP_CT_AND,
	OP_CT_OR,
	OP_CT_CONCAT,
	OP_CT_CONCAT_ASSIGN,

	OP_GT,
	OP_GE,
	OP_LT,
	OP_LE,
	OP_NE,
	OP_EQ,

	// Vec comparisons
	OP_VEC_GT,
	OP_VEC_GE,
	OP_VEC_LT,
	OP_VEC_LE,
	OP_VEC_NE,
	OP_VEC_EQ,

	// Only "assign" BINOPS after this point
	OP_ELVIS,
	OP_ASSIGN,
	OP_ADD_ASSIGN,
	OP_BIT_AND_ASSIGN,
	OP_BIT_OR_ASSIGN,
	OP_BIT_XOR_ASSIGN,
	OP_DIV_ASSIGN,
	OP_MOD_ASSIGN,
	OP_MULT_ASSIGN,
	OP_SHR_ASSIGN,
	OP_SHL_ASSIGN,
	OP_SUB_ASSIGN,
}

fn OperatorKind binaryop_from_token(TokenKind kind)
{
	switch (kind)
	{
		case ASTERISK: return OP_MULT;
		case DIV: return OP_DIV;
		case PLUS: return OP_ADD;
		case MINUS: return OP_SUB;
		case MOD: return OP_MOD;
		case AND: return OP_AND;
		case OR: return OP_OR;
		case QUESTQUEST: return OP_ELSE;
		case AMP: return OP_BIT_AND;
		case BIT_OR: return OP_BIT_OR;
		case BIT_XOR: return OP_BIT_XOR;
		case EQEQ: return OP_EQ;
		case NOT_EQUAL: return OP_NE;
		case LESS: return OP_LT;
		case LESS_EQ: return OP_LE;
		case GREATER: return OP_GT;
		case GREATER_EQ: return OP_GE;
		case EQ: return OP_ASSIGN;
		case MULT_ASSIGN: return OP_MULT_ASSIGN;
		case PLUS_ASSIGN: return OP_ADD_ASSIGN;
		case MINUS_ASSIGN: return OP_SUB_ASSIGN;
		case DIV_ASSIGN: return OP_DIV_ASSIGN;
		case MOD_ASSIGN: return OP_MOD_ASSIGN;
		case BIT_AND_ASSIGN: return OP_BIT_AND_ASSIGN;
		case BIT_OR_ASSIGN: return OP_BIT_OR_ASSIGN;
		case BIT_XOR_ASSIGN: return OP_BIT_XOR_ASSIGN;
		case RSHIFT_ASSIGN: return OP_SHR_ASSIGN;
		case LSHIFT_ASSIGN: return OP_SHL_ASSIGN;
		case ELVIS: return OP_ELVIS;
		default:
			unreachable("unknown binaryop kind: %s", kind);
	}
}

enum VaargKind
{
	VACOUNT,
	VAARG_INDEX
}

enum VarDeclKind : char
{
	VAR_LOCAL,
	VAR_GLOBAL,
	VAR_FIELD,
	VAR_PARAM
}

enum UnaryOpKind : char
{
	UNARYOP_ERROR,
	UNARYOP_DEREF,
	UNARYOP_ADDR,
	UNARYOP_NEG,
	UNARYOP_PLUS,
	UNARYOP_BITNEG,
	UNARYOP_NOT,
	UNARYOP_INC,
	UNARYOP_DEC,
	UNARYOP_TADDR,
}

fn UnaryOpKind? unaryop_from_token(TokenKind kind)
{
	switch (kind)
	{
		case ASTERISK: return UNARYOP_DEREF;
		case AMP: return UNARYOP_ADDR;
		case AND: return UNARYOP_TADDR;
		case BIT_NOT: return UNARYOP_BITNEG;
		case BANG: return UNARYOP_NOT;
		case BANGBANG: return UNARYOP_NOT;
		case MINUS: return UNARYOP_NEG;
		case PLUS: return UNARYOP_PLUS;
		case PLUSPLUS: return UNARYOP_INC;
		case MINUSMINUS: return UNARYOP_DEC;
		default: return NOT_FOUND~;
	}
}

enum AliasDeclKind : char
{
	TYPE_ALIAS,
	MODULE_ALIAS,
	IDENT_ALIAS,
}

enum DeferKind : char
{
	NORMAL,
	TRY,
	// defer try ...
	CATCH,
	// defer catch ...
	CATCH_VAR
	// defer (catch var) ...
}

enum RangeKind : char
{
	DYNAMIC,
	CONST_END,
	CONST_LEN,
	CONST_RANGE,
	SINGLE_ELEMENT,
}

enum TypeInfoKind
{
	INVALID,
	IDENTIFIER,
	CT_IDENTIFIER,
	TYPEOF,
	VATYPE,
	EVALTYPE,
	TYPEFROM,
	ARRAY,
	VECTOR,
	INFERRED_ARRAY,
	INFERRED_VECTOR,
	SLICE,
	FUNCTION,
	POINTER,
	GENERIC
}

enum TypeKind : char
{
	TYPE_VOID,
	TYPE_BOOL,
	TYPE_I8,
	TYPE_I16,
	TYPE_I32,
	TYPE_I64,
	TYPE_I128,
	TYPE_U8,
	TYPE_U16,
	TYPE_U32,
	TYPE_U64,
	TYPE_U128,
	TYPE_F16,
	TYPE_BF16,
	TYPE_F32,
	TYPE_F64,
	TYPE_F128,
	TYPE_USIZE,
	TYPE_IPTR,
	TYPE_UPTR,

	TYPE_ARRAY,
	TYPE_ALIAS,
	TYPE_POINTER,
	TYPE_STRUCT,
    TYPE_UNION,
    TYPE_BITSTRUCT,
    TYPE_ENUM,
}

enum BitSizes : char (uint bits)
{
	BIT1     { 8 },
	BITS8    { 8 },
    BITS16   { 16 },
    BITS32   { 32 },
    BITS64   { 64 },
    BITS128  { 128 },
    BITS256  { 256 },
}

fn BitSizes int_to_bit_size(sz bits)
{
	switch (bits)
	{
		case 1: return BIT1;
		case 8: return BITS8;
		case 16: return BITS16;
		case 32: return BITS32;
		case 64: return BITS64;
		case 128: return BITS128;
		case 256: return BITS256;
		default: unreachable("Not a valid bit size");
	}
}

enum AttributeKind : char
{
	CUSTOM,
	PRIVATE,
	DEPRECATED,
	NODISCARD,
	IF,
}

enum Visibility : char
{
	PUBLIC,
	PRIVATE,
}

enum DesignatorKind : char
{
	PERIOD,
	INDEX,
	RANGE,
}

enum AccessKind : char
{
	INSTANCE, // field.
	STATIC    // Type::
}

<*
 Payload mapping:
- TYPE_IDENTIFIER: TypeExpr.unresolved
- TYPE_POINTER and TYPE_SLICE: TypeExpr.modify
- TYPE_ARRAY and TYPE_VECTOR: TypeExpr.array
- TYPE_GENERIC: TypeExpr.generic
- TYPE_FUNCTION: TypeExpr.func
*>
enum TypeExprKind : char
{
	TYPE_IDENTIFIER,
	TYPE_POINTER,
	TYPE_ARRAY,
	TYPE_SLICE,
	TYPE_VECTOR,
	TYPE_GENERIC,
	TYPE_TYPEOF,
	TYPE_TYPEFROM,
	TYPE_FUNCTION
}
