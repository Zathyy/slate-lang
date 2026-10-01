#pragma once

#include "primitives.h"

enum class DeclKind : u8 {
    Fn,
    Struct,
    Var,
};

enum class StmtKind : u8 {
    Compound,
    Return,
    Expr,
};

enum class ExprKind : u8 {
    Binary,
    Call,
    Ident,
    Literal,
    Access
};