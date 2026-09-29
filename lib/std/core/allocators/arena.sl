module std::core::allocators;

struct Arena
{
    Page* first;
    Page* current;
    usize size;
}

[private]
struct Page
{
    u8* memory;
    Page* next;
    usize capacity;
    usize used;
}

fn Arena.init(&self, usize page_size)
{
}
