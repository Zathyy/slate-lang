#pragma once
#include <cstdio>
#include <utility>

#include "build_context.h"
#include "string.h"

enum class DiagnosticLevel : char {
    NOTE,
    INFO,
    WARN,
    ERROR
};

struct Ansi {
    static constexpr const char* RESET = "\033[0m";
    static constexpr const char* BOLD = "\033[1m";
    static constexpr const char* RED = "\033[31m";
    static constexpr const char* GREEN = "\033[32m";
    static constexpr const char* BRIGHT_BLUE = "\033[94m";
    static constexpr const char* BG_YELLOW = "\033[43m";
};

template <typename... Args>
void diagnose(const Range range, DiagnosticLevel level, const char* fmt, Args&&... args) {
    SourceFile* sf = source_file_get(range.file_id);
    if (!sf) {
        std::fprintf(stderr, "Error: No source file found for FileID: %u\n", range.file_id);
        return;
    }

    const char* color = Ansi::BRIGHT_BLUE;
    const char* level_str = "note";
    switch (level) {
        case DiagnosticLevel::NOTE:  color = Ansi::BRIGHT_BLUE; level_str = "note"; break;
        case DiagnosticLevel::INFO:  color = Ansi::GREEN;       level_str = "info"; break;
        case DiagnosticLevel::WARN:  color = Ansi::BG_YELLOW;   level_str = "warn"; break;
        case DiagnosticLevel::ERROR: color = Ansi::RED;         level_str = "error"; break;
    }

    std::fprintf(stderr, "%.*s:%u:%u: %s%s%s:%s ",
                 (int)sf->path.len, (const char*)sf->path.data,
                 range.start.line + 1, range.start.column + 1,
                 color, Ansi::BOLD, level_str, Ansi::RESET);

    std::fprintf(stderr, fmt, std::forward<Args>(args)...);
    std::fprintf(stderr, "\n");

    String content = sf->content;
    if (content.len == 0) return;

    u32 max_line = range.start.line + 1;
    int line_num_width = 4;
    int digits = 0;
    u32 temp_line = max_line;
    while (temp_line > 0) {
        digits++;
        temp_line /= 10;
    }
    if (digits > line_num_width) line_num_width = digits;

    usize current_line_idx = 0;
    usize line_start_offset = 0;

    for (usize i = 0; i <= content.len; i++) {
        if (i == content.len || content.data[i] == '\n') {
            usize line_len = i - line_start_offset;
            if (line_len > 0 && content.data[line_start_offset + line_len - 1] == '\r') {
                line_len--;
            }

            if (current_line_idx >= (range.start.line > 3 ? range.start.line - 3 : 0) &&
                current_line_idx <= range.start.line) {

                // Print gutter
                std::fprintf(stderr, "%*u | ", line_num_width, (unsigned int)(current_line_idx + 1));

                // Print line content with tab expansion (4 spaces)
                for (usize j = 0; j < line_len; j++) {
                    u8 c = content[line_start_offset + j];
                    if (c == '\t') {
                        std::fprintf(stderr, "    ");
                    } else {
                        std::fprintf(stderr, "%c", c);
                    }
                }
                std::fprintf(stderr, "\n");

                // If this is the error line, print carets underneath
                if (current_line_idx == range.start.line) {
                    int gutter_width = line_num_width + 3;
                    for (int j = 0; j < gutter_width; j++) {
                        std::fprintf(stderr, " ");
                    }

                    // Align carets with column position (accounting for tabs up to column)
                    u32 max_col = std::min((u32)range.start.column, (u32)line_len);
                    for (u32 j = 0; j < max_col; j++) {
                        if (content[line_start_offset + j] == '\t') {
                            std::fprintf(stderr, "    ");
                        } else {
                            std::fprintf(stderr, " ");
                        }
                    }

                    std::fprintf(stderr, "%s", Ansi::RED);
                    usize caret_len = 1;
                    if (range.end.line == range.start.line && range.end.column > range.start.column) {
                        caret_len = range.end.column - range.start.column;
                    }
                    for (usize j = 0; j < caret_len; j++) {
                        std::fprintf(stderr, "^");
                    }
                    std::fprintf(stderr, "%s\n", Ansi::RESET);
                }
            }

            current_line_idx++;
            line_start_offset = i + 1;
            if (current_line_idx > range.start.line) break;
        }
    }
}

#define diag_note(range, fmt, ...) diagnose((range), DiagnosticLevel::NOTE, (fmt), ##__VA_ARGS__)
#define diag_info(range, fmt, ...) diagnose((range), DiagnosticLevel::INFO, (fmt), ##__VA_ARGS__)
#define diag_warn(range, fmt, ...) diagnose((range), DiagnosticLevel::WARN, (fmt), ##__VA_ARGS__)

#define diag_error(range, fmt, ...) do { \
    diagnose((range), DiagnosticLevel::ERROR, (fmt), ##__VA_ARGS__); \
} while(0)