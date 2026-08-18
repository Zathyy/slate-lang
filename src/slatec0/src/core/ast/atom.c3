module slate::core::ast;

import std::collections::list;

struct Error
{
	inline Node node;
}

struct Ident
{
	Range range;
	String text;
}

struct PathAtom
{
	inline Node node;
	Ident* path;
	bool is_prefix;
}
