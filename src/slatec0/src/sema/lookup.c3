module slate::sema::lookup;

import slate::core;
import slate::core::arch;
import llvm;

uint next_typeid = 1;

fn Lookup* create(CompilerContext* context)
{
	Lookup* lookup = alloc::new(context.alloc, Lookup);

	Allocator alloc = context.alloc;

	lookup.builtin_types.init(alloc);
	lookup.types.init(alloc);
	lookup.pointer_cache.init(alloc);
	lookup.ref_cache.init(alloc);
	lookup.array_cache.init(alloc);
	lookup.slice_cache.init(alloc);
	lookup.alloc = alloc;
	lookup.target = context.target;

	init_builtin_types(lookup);

	return lookup;
}

fn Type* register_type(Lookup* lookup, Allocator alloc, String qname, String name, Decl* decl, TypeKind kind)
{
	Type* type = alloc::new(alloc, Type);

	type.name = name;
	type.kind = kind;
	type.status = UNRESOLVED;
	type.data.decl = decl;

	if (kind != TYPE_FN)
	{
		type.type_id = next_typeid++;
	}

	if (kind != TYPE_ALIAS)
    {
        type.canonical = type;
    }

    lookup.types.set(qname, type);

	return type;
}

fn Type* create_builtin(Lookup* lookup, String name,
	TypeKind kind, BitSizes bits, char bytes, LLVMTypeRef llvm_type)
{
	Type* type = alloc::new(lookup.alloc, Type);
	type.name = name;
	type.kind = kind;
	type.status = RESOLVED;
	type.llvm_type = llvm_type;

	type.canonical = type;

	type.data.builtin.bitsize = bits.ordinal;
	type.data.builtin.bytesize = bytes;

	type.type_id = next_typeid++;

	AlignData align;
	switch (kind)
	{
		case TYPE_F32:
		case TYPE_F64:
			align = lookup.target.layout.floats[bits.ordinal];
			break;
		default:
			align = lookup.target.layout.integers[bits.ordinal];
	}

	type.data.builtin.abi_alignment = (char)align.align;
	type.data.builtin.pref_alignment = (char)align.pref_align;
	type.size = (uint)bytes;
    type.alignment = (uint)align.align;

	lookup.builtin_types.set(name, type);

	return type;
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
    Type* u32_type = create_builtin(lookup, "u32", TYPE_U32, BITS32, 4, llvm::int_32_type());

    create_builtin(lookup, "i64", TYPE_I64, BITS64, 8, llvm::int_64_type());
    create_builtin(lookup, "u64", TYPE_U64, BITS64, 8, llvm::int_64_type());

    create_builtin(lookup, "f32", TYPE_F32, BITS32, 4, llvm::float_type());
    create_builtin(lookup, "f64", TYPE_F64, BITS64, 8, llvm::double_type());

    create_builtin(lookup, "usize", TYPE_USIZE, pbits, psize, ptr_llvm_type);
    create_builtin(lookup, "uptr", TYPE_UPTR, pbits, psize, ptr_llvm_type);

    // typeid keyword primitive alias to u32
    Type* typeid_type = create_builtin(lookup, "typeid", TYPE_ALIAS, BITS32, 4, llvm::int_32_type());
    typeid_type.canonical = u32_type;
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
    ptr_type.canonical = ptr_type;
    ptr_type.size = arch::ptr_size(lookup.target.arch);
    ptr_type.alignment = arch::ptr_size(lookup.target.arch);
    ptr_type.data.ptr = base;

    lookup.pointer_cache.set(base, ptr_type);
    return ptr_type;
}

<*
 Returns or creates a canonical ref Type (&T)
*>
fn Type* get_or_create_ref(Lookup* lookup, Type* base)
{
    if (!base) return null;

    if (Type* cached = lookup.ref_cache.get(base) ?? null)
    {
        return cached;
    }

    Type* ref_type = alloc::new(lookup.alloc, Type);
    ref_type.kind = TYPE_REF;
    ref_type.status = RESOLVED;
    ref_type.canonical = ref_type;
    ref_type.size = arch::ptr_size(lookup.target.arch);
    ref_type.alignment = arch::ptr_size(lookup.target.arch);
    ref_type.data.ptr = base;

    lookup.ref_cache.set(base, ref_type);
    return ref_type;
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
    arr_type.canonical = arr_type;
    arr_type.size = (uint)(elem.size * len);
    arr_type.alignment = elem.alignment;
    arr_type.data.array = key;

    lookup.array_cache.set(key, arr_type);
    return arr_type;
}

<*
 Returns or creates a canonical Slice Type (T[])
*>
fn Type* get_or_create_slice(Lookup* lookup, Type* elem)
{
    if (!elem) return null;

    if (Type* cached = lookup.slice_cache.get(elem) ?? null)
    {
        return cached;
    }

    Type* slice_type = alloc::new(lookup.alloc, Type);
    slice_type.kind = TYPE_SLICE;
    slice_type.status = RESOLVED;
    slice_type.canonical = slice_type;

    // Fat pointer layout: { ptr: T*, len: usize }
    uint ptr_sz = arch::ptr_size(lookup.target.arch);
    slice_type.size = ptr_sz * 2;
    slice_type.alignment = ptr_sz;
    slice_type.data.slice = elem;

    lookup.slice_cache.set(elem, slice_type);
    return slice_type;
}

fn bool type_eq(Type* a, Type* b)
{
	if (!a || !b) return false;

    Type* ca = a.canonical != null ? a.canonical : a;
    Type* cb = b.canonical != null ? b.canonical : b;

    return ca == cb;
}

fn bool Type.eq(&self, Type* other) @operator(==)
{
	return type_eq(self, other) @inline;
}

fn bool Type.is_integer(&self)
{
	Type* canon = self.canonical != null ? self.canonical : self;
	switch (canon.kind)
	{
		case TYPE_I8:
		case TYPE_I16:
		case TYPE_I32:
		case TYPE_I64:
		case TYPE_U8:
		case TYPE_U16:
		case TYPE_U32:
		case TYPE_U64:
		case TYPE_USIZE:
		case TYPE_IPTR:
		case TYPE_UPTR:
			return true;
		default:
			return false;
	}
}

fn bool Type.is_signed_int(&self)
{
	Type* canon = self.canonical != null ? self.canonical : self;
	switch (canon.kind)
	{
		case TYPE_I8:
		case TYPE_I16:
		case TYPE_I32:
		case TYPE_I64:
		case TYPE_IPTR:
			return true;
		default:
			return false;
	}
}

fn bool Type.is_float(&self)
{
	Type* canon = self.canonical != null ? self.canonical : self;
	switch (canon.kind)
	{
		case TYPE_F32:
		case TYPE_F64:
			return true;
		default:
			return false;
	}
}

fn bool Type.is_numeric(&self)
{
    Type* canon = self.canonical != null ? self.canonical : self;
    return canon.is_integer() || canon.is_float();
}

fn Type* primitive_type(Lookup* self, TypeKind kind)
{
	switch (kind)
	{
		case TYPE_VOID:  return self.builtin_types.get("void")!!;
		case TYPE_BOOL:  return self.builtin_types.get("bool")!!;
		case TYPE_I8:    return self.builtin_types.get("i8")!!;
		case TYPE_I16:   return self.builtin_types.get("i16")!!;
		case TYPE_I32:   return self.builtin_types.get("i32")!!;
		case TYPE_I64:   return self.builtin_types.get("i64")!!;
		case TYPE_U8:    return self.builtin_types.get("u8")!!;
		case TYPE_U16:   return self.builtin_types.get("u16")!!;
		case TYPE_U32:   return self.builtin_types.get("u32")!!;
		case TYPE_U64:   return self.builtin_types.get("u64")!!;
		case TYPE_F32:   return self.builtin_types.get("f32")!!;
		case TYPE_F64:   return self.builtin_types.get("f64")!!;
		case TYPE_USIZE: return self.builtin_types.get("usize")!!;
		case TYPE_ALIAS: return self.builtin_types.get("typeid")!!;
		default: unreachable("Not a primitive type");
	}
}

fn bool fits_in_integer(ulong val, bool is_negative, Type* target)
{
    if (is_negative)
    {
        switch (target.kind)
        {
            case TYPE_I8:    return val <= ichar::max;
            case TYPE_I16:   return val <= short::max;
            case TYPE_I32:   return val <= int::max;
            case TYPE_I64:   return val <= long::max;
            default:         return false;
        }
    }

    // Positive range checks
    switch (target.kind)
    {
    	case TYPE_U8:    return val <= char::max;   // 255
        case TYPE_I8:    return val <= ichar::max;  // 127
        case TYPE_U16:   return val <= ushort::max; // 65535
        case TYPE_I16:   return val <= short::max;  // 32767
        case TYPE_U32:   return val <= uint::max;   // 4294967295
        case TYPE_I32:   return val <= int::max;    // 2147483647
        case TYPE_U64:
        case TYPE_USIZE: return true;               // Fits in ulong
        case TYPE_I64:   return val <= long::max;   // 9223372036854775807
        default:         return false;
    }
}

fn uint Type.get_align(Type* type)
{
    if (type == null) return 8;
    return type.canonical != null ? type.canonical.alignment : type.alignment;
}

fn Type* Type.get_concrete(Type* type)
{
	return type.canonical != null ? type.canonical : type;
}
