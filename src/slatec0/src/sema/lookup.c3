module slate::sema::lookup;

import slate::core;
import slate::core::arch;
import llvm;

fn Lookup* create(CompilerContext* context)
{
	Lookup* lookup = alloc::new(context.alloc, Lookup);

	Allocator alloc = context.alloc;

	lookup.types.init(alloc);
	lookup.pointer_cache.init(alloc);
	lookup.array_cache.init(alloc);
	lookup.alloc = alloc;
	lookup.target = context.target;

	init_builtin_types(lookup);

	return lookup;
}

fn void register_type(Lookup* lookup, Allocator alloc, String name, Node* node, LLVMTypeRef llvm_type)
{
	Type* type = alloc::new(alloc, Type);

	type.name = name;
	type.data.node = node;
	type.status = UNRESOLVED;
	type.llvm_type = llvm_type;

	lookup.types.set(name, type);
}

fn void create_builtin(Lookup* lookup, String name,
	TypeKind kind, BitSizes bits, char bytes, LLVMTypeRef llvm_type)
{
	Type* type = alloc::new(lookup.alloc, Type);
	type.name = name;
	type.kind = kind;
	type.status = RESOLVED;
	type.llvm_type = llvm_type;

	type.data.builtin.bitsize = bits.ordinal;
	type.data.builtin.bytesize = bytes;

	AlignData align;
	switch (kind)
	{
		case TYPE_F16:
		case TYPE_F32:
		case TYPE_F64:
		case TYPE_F128:
			align = lookup.target.layout.floats[bits.ordinal];
		default:
			align = lookup.target.layout.integers[bits.ordinal];
	}

	type.data.builtin.abi_alignment = (char)align.align;
	type.data.builtin.pref_alignment = (char)align.pref_align;

	lookup.types.set(name, type);
}

fn void init_builtin_types(Lookup* lookup)
{
	char psize = arch::ptr_size(lookup.target.arch);
    BitSizes pbits = arch::is_64bit(lookup.target.arch) ? BITS64 : BITS32;
    LLVMTypeRef ptr_llvm_type = arch::is_64bit(lookup.target.arch)
        ? llvm::int_64_type()
        : llvm::int_32_type();

    create_builtin(lookup, "void", TYPE_VOID, BIT1, 1, llvm::void_type());
    create_builtin(lookup, "bool", TYPE_BOOL, BITS8, 1, llvm::int_1_type());

    create_builtin(lookup, "i8",  TYPE_I8,  BITS8,  1, llvm::int_8_type());
    create_builtin(lookup, "u8",  TYPE_U8,  BITS8,  1, llvm::int_8_type());

    create_builtin(lookup, "i16", TYPE_I16, BITS16, 2, llvm::int_16_type());
    create_builtin(lookup, "u16", TYPE_U16, BITS16, 2, llvm::int_16_type());

    create_builtin(lookup, "i32", TYPE_I32, BITS32, 4, llvm::int_32_type());
    create_builtin(lookup, "u32", TYPE_U32, BITS32, 4, llvm::int_32_type());

    create_builtin(lookup, "i64", TYPE_I64, BITS64, 8, llvm::int_64_type());
    create_builtin(lookup, "u64", TYPE_U64, BITS64, 8, llvm::int_64_type());

    create_builtin(lookup, "f32", TYPE_F32, BITS32, 4, llvm::float_type());
    create_builtin(lookup, "f64", TYPE_F64, BITS64, 8, llvm::double_type());

    create_builtin(lookup, "usize", TYPE_USIZE, pbits, psize, ptr_llvm_type);
}

<*
 Returns or creates a canonical Pointer Type (*T)
*>
fn Type* get_or_create_pointer(Lookup* lookup, Type* base)
{
    if (!base) return null;

    if (Type* cached = lookup.pointer_cache.get(base) ?? null)
    {
        return cached;
    }

    Type* ptr_type = alloc::new(lookup.alloc, Type);
    ptr_type.kind = TYPE_POINTER;
    ptr_type.status = RESOLVED;
    ptr_type.size = arch::ptr_size(lookup.target.arch);
    ptr_type.alignment = arch::ptr_size(lookup.target.arch);
    ptr_type.data.ptr = base;

    lookup.pointer_cache.set(base, ptr_type);
    return ptr_type;
}

<*
 Returns or creates a canonical Array Type (T[N])
*>
fn Type* get_or_create_array(Lookup* lookup, Type* elem, ulong len)
{
    if (!elem) return null;

    TypeArray key = { .base = elem, .len = len };
    if (Type* cached = lookup.array_cache.get(key) ?? null)
    {
        return cached;
    }

    Type* arr_type = alloc::new(lookup.alloc, Type);
    arr_type.kind = TYPE_ARRAY;
    arr_type.status = RESOLVED;
    arr_type.size = (uint)(elem.size * len);
    arr_type.alignment = elem.alignment;
    arr_type.data.array = key;

    lookup.array_cache.set(key, arr_type);
    return arr_type;
}

fn bool type_eq(Type* a, Type* b)
{
    if (!a || !b) return false;

    while (a && a.kind == TYPE_ALIAS) a = a.data.ptr;
    while (b && b.kind == TYPE_ALIAS) b = b.data.ptr;

    return a == b;
}

fn bool Type.eq(&self, Type* other) @operator(==)
{
	return type_eq(self, other) @inline;
}
