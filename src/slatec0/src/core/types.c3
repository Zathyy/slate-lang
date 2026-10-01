module slate::core;

import slate::lexer;
import std::collections;

struct CompilerContext
{
	Allocator alloc;
	HashMap{FileID::inner, SourceFile*} files;
	HashMap{String, Module*} modules;
	List{String} features;
	FileID current_source_file;
	Target target;
	uint error_count;
}

struct Lookup
{
	HashMap{String, Type*} builtin_types;
	HashMap{String, Type*} types;
	HashMap{void*, Type*} pointer_cache;
	HashMap{void*, Type*} ref_cache;
	HashMap{TypeArray, Type*} array_cache;
	HashMap{void*, Type*} slice_cache;
	Allocator alloc;
	Target target;
}

struct SourceFile
{
	Lexer* lexer;
	String path;
	String content;
	Ast ast;
	FileID id;
}

struct Module
{
	String name;
	HashMap{NodeID, Node*} node_map;
	List{Node*} nodes;
	List{ModuleDecl*} module_decls;
	Scope* scope;
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
	bool is_optional;
	uint size;
	uint alignment;
	uint type_id;
	String name;

	Type* canonical;

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
        Type* slice;
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
