(* Tokens & Identifiers *)
IDENT           ::= [a-zA-Z_] [a-zA-Z0-9_]*
INT_LITERAL     ::= [0-9]+
FLOAT_LITERAL   ::= [0-9]+ '.' [0-9]+
STRING_LITERAL  ::= '"' ( [^"\\] | '\\' . )* '"'
CHAR_LITERAL    ::= '\'' ( [^'\\] | '\\' . ) '\''

(* Keywords *)
KW_MODULE       ::= "module"
KW_IMPORT       ::= "import"
KW_STRUCT       ::= "struct"
KW_ENUM         ::= "enum"
KW_TYPEDEF      ::= "typedef"
KW_FN           ::= "fn"
KW_VAR          ::= "var"
KW_CONST        ::= "const"
KW_IF           ::= "if"
KW_ELSE         ::= "else"
KW_WHILE        ::= "while"
KW_FOR          ::= "for"
KW_RETURN       ::= "return"

(* Operators & Punctuation *)
SCOPE           ::= "::"
ARROW           ::= "->"
EQ              ::= "="
EQEQ            ::= "=="
NOT_EQ          ::= "!="
LESS            ::= "<"
GREATER         ::= ">"
LESS_EQ         ::= "<="
GREATER_EQ      ::= ">="
PLUS            ::= "+"
MINUS           ::= "-"
ASTERISK        ::= "*"
SLASH           ::= "/"
PERCENT         ::= "%"
AMP             ::= "&"
PIPE            ::= "|"
LPAREN          ::= "("
RPAREN          ::= ")"
LBRACE          ::= "{"
RBRACE          ::= "}"
LBRACKET        ::= "["
RBRACKET        ::= "]"
EOS             ::= ";"
COMMA           ::= ","
DOT             ::= "."