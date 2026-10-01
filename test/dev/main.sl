module main;

import foo;
import std::libc;
import std::core::ascii;

struct Bar
{
    i32 a;
}

fn Bar.get() -> void 
{

}

fn main() -> i32
{
    printf("%s", "Hello there\n");

    String foo = "bababoi";
    libc::printf("%s\n", foo);

    ascii::is_alpha('h');

    return 0;
}

fn bar(Bar* string)
{
    String b;

    Bar tttt;
}
