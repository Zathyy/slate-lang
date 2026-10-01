#pragma once

#include "common/collections/list.h"
#include "common/common.h"
#include "common/enums.h"
#include "common/primitives.h"
#include "common/string.h"

struct Decl;
struct Stmt;
struct Expr;

struct FnDecl
{
    String name;
    Expr* ret_type;
    Stmt* body;
};

struct StructDecl
{
    String name;
};

struct Decl
{
    DeclKind kind;
    Range range;
    union {
        FnDecl fn;
        StructDecl struct_def;
        //VarDecl var;
    };
};

struct ReturnStmt
{
    Expr* expr;
};

struct CompoundStmt
{
    List<Stmt*> stmts;
};

struct ExprStmt
{
    Expr* expr;
};

struct Stmt
{
    StmtKind kind;
    Range range;
    union {
        ReturnStmt return_stmt;
        CompoundStmt compound;
        ExprStmt expr_stmt;
    };
};

struct BinaryExpr
{
    Expr* left;
    Expr* right;
    //OperatorKind op;
};

struct Expr
{
    ExprKind kind;
    Range range;
    //Type* resolved_type;
    union {
        BinaryExpr binary;
        //CallExpr call;
        //LiteralExpr literal;
        //IdentExpr ident;
    };
};