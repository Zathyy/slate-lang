#pragma once

#include <cassert>
#include <cstring>
#include "primitives.h"

#define STR_FMT "%.*s"
#define STR_ARG(s) (int)(s).len, (const char*)(s).data

struct String
{
    u8* data;
    usize len;

    constexpr String() : data(nullptr), len(0) {}

    String(const char* str)
        : data(const_cast<u8*>(reinterpret_cast<const u8*>(str))),
          len(str ? std::strlen(str) : 0) {}

    constexpr String(u8* data, usize len) : data(data), len(len) {}

    const u8& operator[](const usize i) const
    {
        assert(i < len && "index out of bounds");
        return data[i];
    }

    bool operator==(const String b) const
    {
        if (len != b.len) return false;
        if (len == 0) return true;
        return memcmp(data, b.data, len) == 0;
    }
};

inline u64 get_hash(const String s) {
    u64 hash = 14695981039346656037ULL;
    for (usize i = 0; i < s.len; i++) {
        hash ^= s.data[i];
        hash *= 1099511628211ULL;
    }
    return hash;
}

namespace string {

    inline size_t length(const String& str) { return str.len; }
    inline bool empty(const String& str) { return str.len == 0; }

    constexpr size_t NPOS = static_cast<size_t>(-1);

    inline void free(String *str) {
        delete[] str->data;
        *str = {};
    }

    inline String substring(const String& str, const size_t offset, size_t count = NPOS) {
        assert(offset <= str.len);
        const size_t remaining = str.len - offset;
        count = std::min(count, remaining);
        return { str.data + offset, count };
    }

    inline bool starts_with(const String& str, const char character)
    {
        return str.len > 0 && str.data[0] == character;
    }

    inline bool starts_with(const String& str, const String prefix)
    {
        if (prefix.len > str.len) return false;
        return memcmp(str.data, prefix.data, prefix.len) == 0;
    }

    inline bool ends_with(const String& str, const char character)
    {
        return str.len > 0 && str.data[str.len - 1] == character;
    }

    inline bool ends_with(const String& str, const String suffix)
    {
        if (suffix.len > str.len) return false;
        return memcmp(str.data + (str.len - suffix.len), suffix.data, suffix.len) == 0;
    }

    inline size_t find_first_of(const String& str, const char character, const size_t startOffset = 0)
    {
        for (size_t i = startOffset; i < str.len; ++i)
        {
            if (str.data[i] == character)
            {
                return i;
            }
        }
        return NPOS;
    }

    inline size_t find_last_of(const String& str, char character)
    {
        if (str.len == 0) return NPOS;

        for (size_t i = str.len; i > 0; --i)
        {
            if (str.data[i - 1] == character)
            {
                return i - 1;
            }
        }

        return NPOS;
    }

    inline size_t find_last_of(const String& str, String characters)
    {
        if (str.len == 0 || empty(characters)) return NPOS;

        for (size_t i = str.len; i > 0; --i)
        {
            const u8 current = str.data[i - 1];

            // Check if current char matches any in the search set
            for (size_t j = 0; j < length(characters); ++j)
            {
                if (current == characters[j])
                {
                    return i - 1;
                }
            }
        }

        return NPOS;
    }

} // namespace string