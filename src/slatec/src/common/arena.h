#pragma once

#include <cmath>
#include <string>
#include <unordered_map>
#include <vector>

#include "primitives.h"

static size align_up(const size value, const size align) {
    return (value + align - 1) & ~(align - 1);
}

struct ArenaPage {
    unsigned char* memory{};
    size capacity{};
    size used{};
    ArenaPage* next{};
};

namespace arena::page {

    inline void init(ArenaPage* page, const size capacity) {
        page->capacity = capacity;
        page->memory = new unsigned char[capacity];
    }

    inline void free(ArenaPage* page) {
        delete[] page->memory;
    }

}

struct Arena {
    ArenaPage* first_page{};
    ArenaPage* current_page{};
    size page_size{};
};

namespace arena {

    inline void init(Arena* arena, size page_size = 8192) {
        arena->page_size = page_size;
        arena->first_page = new ArenaPage();
        arena->current_page = arena->first_page;

        page::init(arena->current_page, page_size);
    }

    template<typename T>
    T* allocate(Arena& arena, const size count = 1) {
        const size alignment = alignof(T);
        const size alloc_size = count * sizeof(T);

        size aligned_used = align_up(arena.current_page->used, alignment);

        if (aligned_used + alloc_size > arena.current_page->capacity) {
            const size new_page_size = std::max(arena.page_size, alloc_size + alignment);

            auto* new_page = new ArenaPage();
            page::init(new_page, new_page_size);
            arena.current_page->next = new_page;
            arena.current_page = new_page;

            aligned_used = align_up(arena.current_page->used, alignment);
        }

        T* ptr = reinterpret_cast<T*>(arena.current_page->memory + aligned_used);
        arena.current_page->used = aligned_used + alloc_size;

        return ptr;
    }

    template<typename T, typename... Args>
    requires std::is_constructible_v<T>
    T* create(Arena* arena, Args&&... args) {
        void* raw_mem = allocate<T>(arena, 1);
        return ::new (raw_mem) T(std::forward<Args>(args)...);
    }

    inline void reset(Arena* arena) {
        ArenaPage* current = arena->first_page;
        while (current != nullptr) {
            current->used = 0;
            current = current->next;
        }
        arena->current_page = arena->first_page;
    }

    inline void free(Arena* arena) {
        ArenaPage* current = arena->first_page;
        while (current) {
            ArenaPage* next = current->next;
            page::free(current);
            delete current;
            current = next;
        }
    }
}


template <typename T>
class ArenaAllocator {
public:
    using value_type = T;
    using pointer = T*;
    using const_pointer = const T*;
    using reference = T&;
    using const_reference = const T&;
    using sizeype = size;
    using difference_type = ptrdiff_t;

    Arena* arena;

    ArenaAllocator(Arena& a) noexcept : arena(&a) {}

    template <typename U>
    ArenaAllocator(const ArenaAllocator<U>& other) noexcept : arena(other.arena) {}

    T* allocate(size n) {
        return arena::allocate<T>(arena, n);
    }

    void deallocate(T*, size) noexcept {}

    template <typename U>
    struct rebind {
        using other = ArenaAllocator<U>;
    };

    template <typename U>
    bool operator==(const ArenaAllocator<U>& other) const noexcept {
        return arena == other.arena;
    }

    template <typename U>
    bool operator!=(const ArenaAllocator<U>& other) const noexcept {
        return arena != other.arena;
    }
};

template<typename T>
using ArenaVector = std::vector<T, ArenaAllocator<T>>;

using ArenaString = std::basic_string<char, std::char_traits<char>, ArenaAllocator<char>>;

template<typename K, typename V>
using ArenaUnorderedMap = std::unordered_map<
    K, V,
    std::hash<K>,
    std::equal_to<K>,
    ArenaAllocator<std::pair<const K, V>>
>;