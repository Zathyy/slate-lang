module main;

import foo;
import std::libc;

struct Bar
{
    i32 a;
}

fn main() -> i32
{
    libc::printf("%s", "Hello there");

    return 5;
}

fn bar(Bar* string)
{
    String b;

    Bar tttt;
}
