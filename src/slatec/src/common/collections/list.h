#pragma once

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <concepts>

#include "common/arena.h"

template <typename T>
struct List {
    T* data;
    size_t count;
    size_t capacity;
    Arena* arena;

    T& operator[](size_t index) {
        if (index >= count) {
            std::fprintf(stderr, "Assertion failed: Index %zu out of bounds (count: %zu)\n", index, count);
            std::abort();
        }
        return data[index];
    }
    const T& operator[](size_t index) const {
        if (index >= count) {
            std::fprintf(stderr, "Assertion failed: Index %zu out of bounds (count: %zu)\n", index, count);
            std::abort();
        }
        return data[index];
    }
};

namespace list {
    template<typename T>
    void ensure_capacity(List<T>& list, size_t min_capacity) {
        if (list.capacity >= min_capacity) {
            return;
        }

        size_t new_capacity = list.capacity == 0 ? 8 : list.capacity * 2;
        if (new_capacity < min_capacity) {
            new_capacity = min_capacity;
        }

        T* new_data = arena::allocate<T>(*list.arena, new_capacity);
        list.data = new_data;
        list.capacity = new_capacity;
    }

    template<typename T>
    void init(List<T>& list, Arena* arena, size_t count = 8) {
        list.arena = arena;
        list.data = arena::allocate<T>(*arena, count);
        list.count = 0;
        list.capacity = count;
    }

    template<typename T>
    void free(List<T>& list) {
        *list = {};
    }

    template<typename T>
    void push(List<T>& list, T element) {
        ensure_capacity(list, list.count + 1);
        list.data[list.count++] = element;
    }

    template<typename T>
    requires std::equality_comparable<T>
    void remove(List<T>& list, T element) {
        assert(list != nullptr);
        for (size_t i = 0; i < list.count; ++i) {
            if (list.data[i] == element) {
                // Shift remaining elements down
                for (size_t j = i; j < list.count - 1; ++j) {
                    list[j] = list[j + 1];
                }
                list.count -= 1;
                break;
            }
        }
    }

    template<typename T>
    T pop(List<T>& list) {
        assert(list.count > 0);
        list.count -= 1;
        return list[list.count];
    }

    template<typename T>
    void clear(List<T>& list) {
        list.count = 0;
    }

    template<typename T>
    T at(List<T>& list, size_t index) {
        return list[index];
    }
}

template<typename T>
T* begin(List<T>& list) {
    return list.data;
}

template<typename T>
T* end(List<T>& list) {
    return list.data + list.count;
}

template<typename T>
const T* begin(const List<T>& list) {
    return list.data;
}

template<typename T>
const T* end(const List<T>& list) {
    return list.data + list.count;
}