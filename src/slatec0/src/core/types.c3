module slate::core;

import slate::lexer;
import std::collections;
import slate::sema::lookup;
import slate::sema::registry;
import llvm;

struct CompilerContext
{
	LLVMContextRef llvm_context;
	Allocator alloc;
	Lookup* lookup;
	Registry* registry;
	HashMap{String, SourceFile*} files;
	HashMap{String, Module*} modules;
	SourceFile* current_source_file;
	Target target;
}

struct Lookup
{
	HashMap{String, Type*} types;
	HashMap{void*, Type*} pointer_cache;
	HashMap{TypeArray, Type*} array_cache;
	Allocator alloc;
	Target target;
}

struct SourceFile
{
	Lexer* lexer;
	String path;
	String content;
	Ast ast;
}

struct Module
{
	String name;
	LLVMModuleRef llvm_module;
	HashMap{NodeID, Node*} node_map;
	List{Node*} nodes;
	List{ModuleDecl*} module_decls;
}

struct ParseContext
{
	CompilerContext* context;
	Allocator allocator;
	SourceFile* sf;
	Ast* ast;
	Lexer* lexer;
	Token current;
	int pos;
	int error_count;
}

struct TypeArray
{
	Type* base;
	ulong len;
}

fn bool TypeArray.eq(&self, TypeArray other) @operator(==)
{
	return self.base == other.base && self.len == other.len;
}

fn uint TypeArray.hash(&self)
{
	return ((void*)self.base).hash() ^ self.len.hash();
}

struct Type
{
	TypeKind kind;
	ResolveStatus status;
	uint size;
	uint alignment;
	String name;
	LLVMTypeRef llvm_type;

	union data
	{
		Node* node;

		bitstruct builtin : uint
		{
			char bitsize        : 0..7;
			char bytesize       : 8..15;
			char abi_alignment  : 16..23;
			char pref_alignment : 24..31;
		}

        Type* ptr;

        TypeArray array;
	}
}

struct TypeInfo
{
	TypeInfo* next;
	String name;
	String mod;
	Node* node;
	Type* resolved;
	ResolveStatus status;
}

struct VarInfo
{
	VarInfo* next;
	String name;
	String mod;
	Node* node;
	ResolveStatus status;
}

struct FunctionInfo
{
	FunctionInfo* next;
	String mod;
	Node* node;
	ResolveStatus status;
}

struct VariableInfo
{
	String name;
	String mod;
	Node* node;
	ResolveStatus status;
}

struct ImportInfo
{
	String path;
	Node* node;
}

struct Registry
{
	HashMap{String, TypeInfo*} types;
	HashMap{String, VarInfo*} globals;
	HashMap{String, FunctionInfo*} functions;
}

struct Scope
{
	Scope* parent;
	Range range;
	List{Scope*} children;
	HashMap{String, FunctionInfo*} functions;
	HashMap{String, VariableInfo*} variables;
	HashMap{String, TypeInfo*} types;
}

struct Target
{
	OsType os;
	ArchType arch;
	TargetLayout layout;
}

struct AlignData
{
	uint align;
	uint pref_align;
}

struct TargetLayout
{
    AlignData[BitSizes::len] integers;
    AlignData[BitSizes::len] floats;
}

enum ComptimeKind
{
    BOOL,
    INT,
    STRING,
    ENUM,
}

struct ComptimeValue
{
    ComptimeKind kind;
    union
    {
        bool bool_val;
        long int_val;
        String str_val;
        struct enum_val
        {
            Type* type;
            uint variant_id;
        }
    }
}
