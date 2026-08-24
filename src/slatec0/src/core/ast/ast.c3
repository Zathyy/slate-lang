module slate::core::ast;

import std::collections::list;

import slate::core::context @norecurse;

alias NodeArray = Node*[];

typedef NodeID = inline ulong;

NodeID next_node_id = (NodeID)1;

bitstruct NodeFlags : ushort
{
	bool is_inline;
	bool is_static;
	bool is_extern;
	bool is_const;
	bool has_attributes;
	bool has_error;
	bool is_disabled; // disabled means no codegen
}

struct Node
{
	NodeKind kind;
	NodeFlags flags;
	Range range;
	NodeID id;
}

struct Decl
{
	inline Node node;
	Ident* name;
	Type* resolved_type;
	Visibility visibility;
}

struct Stmt
{
	inline Node node;
}

struct Expr
{
	inline Node node;
	Type* resolved_type;
}

<*
 @require self.kind == NodeKind.$eval(@typename_to_constname($Type::name)) : "Invalid kind to cast"
*>
macro Node.as(&self, $Type) => ($Type*)self;

macro Node.is_decl(&self) => self.kind.is_decl();
macro Node.is_stmt(&self) => self.kind.is_stmt();
macro Node.is_expr(&self) => self.kind.is_expr();

fn bool Node.is_valid(&self) @inline
{
	return self.kind != ERROR && !self.flags.has_error;
}

struct Ast
{
	List{Node*} nodes;
	List{Node*} statements;
}

macro Node* Ast.error(&self, Range range)
{
	Node* node = (Node*)self.alloc_node(Error, range);
	node.flags.has_error = true;
	self.nodes.push(node);
	return node;
}

<*
 Allocates and initializes a strongly typed AST node inside the AST arena.
 @param range : "Range of the node"
*>
macro Ast.alloc_node(&self, $Type, Range range)
{
	$Type* node = alloc::new(&context::g_arena, $Type);

	node.kind = NodeKind.$eval(@typename_to_constname($Type::name));
	node.range = range;
	node.id = next_node_id++;
	self.nodes.push(node);

	return node;
}

macro String @typename_to_constname(String $typename) @const
{
	var $name = "";
	$foreach $i, $c : $typename:
		$if $i != 0 &&& $c >= 'A' &&& $c <= 'Z':
			$name +++= "_";
		$endif
		$name +++= @str_upper("" +++ $c);
	$endforeach

	return $name;
}
