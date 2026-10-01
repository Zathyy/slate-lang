#pragma once

#include "common/primitives.h"
#include <utility>

template <typename F>
struct ScopeExit {
    F fn;
    // ReSharper disable once CppNonExplicitConvertingConstructor
    ScopeExit(F&& f) : fn(std::move(f)) {}
    ~ScopeExit() { fn(); }

    ScopeExit(const ScopeExit&) = delete;
    ScopeExit& operator=(const ScopeExit&) = delete;
    ScopeExit(ScopeExit&&) = delete;
    ScopeExit& operator=(ScopeExit&&) = delete;
};

#define DEFER_CONCAT_IMPL(x, y) x##y
#define DEFER_CONCAT(x, y) DEFER_CONCAT_IMPL(x, y)

#define defer ScopeExit DEFER_CONCAT(_defer_guard_, __LINE__) = [&]()

// Scoped checkpoint runner that accepts any callable: void(Arena&)
template <typename F>
inline void temp_scope(Arena* scratch_arena, F&& body) {
    // Save checkpoint
    ArenaPage* orig_page = scratch_arena->current_page;
    size orig_used = scratch_arena->current_page->used;

    // Execute the user's block callback with the scratch arena
    body(*scratch_arena);

    // Roll back extra pages allocated during the scope
    while (scratch_arena->current_page != orig_page) {
        ArenaPage* next = scratch_arena->current_page->next;
        arena::page::free(scratch_arena->current_page);
        delete scratch_arena->current_page;
        scratch_arena->current_page = next;
    }
    // Restore used offset
    scratch_arena->current_page->used = orig_used;
}

// Macro helper for default global scratch arena
#define temp(arena_var) temp_scope(&globals::build.scratch_arena, [&](Arena& arena_var)

typedef u16 FileID;

struct Location
{
    i32 line;
    i32 column;
};

struct Range
{
    Location start;
    Location end;
    FileID file_id;
};
