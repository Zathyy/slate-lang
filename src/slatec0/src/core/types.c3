module slate::core;

import slate::lexer;
import std::collections;
import slate::sema::lookup;
import llvm;

struct CompilerContext
{
	LLVMContextRef llvm_context;
	LLVMTargetMachineRef llvm_target;
	Allocator alloc;
	Lookup* lookup;
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

	struct sema
	{
		Scope* scope;
	}
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
		Decl* decl;

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

struct Scope
{
	Scope* parent;
	Range range;
	List{Scope*} children;
	HashMap{String, Decl*} symbols;
	List{String} imports;
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

fn bool ComptimeValue.eq(&self, ComptimeValue other) @operator(==)
{
	if (self.kind != other.kind) return false;

	switch (self.kind)
	{
		case BOOL: return self.bool_val == other.bool_val;
		case INT:  return self.int_val == other.int_val;
		case STRING: return self.str_val == other.str_val;
		case ENUM:
			if (self.enum_val.type && other.enum_val.type)
			{
				return self.enum_val.type == other.enum_val.type;
			}
			return self.enum_val.variant_id == other.enum_val.variant_id;
	}
}
