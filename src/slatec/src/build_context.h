#pragma once

#include "common/arena.h"
#include "common/collections/list.h"
#include "common/common.h"
#include "common/primitives.h"
#include "common/string.h"

struct SourceFile
{
    String path {};
    String content {};
    u32 file_id = 0;
};

struct BuildContext
{
    Arena permanent_arena {};
    Arena scratch_arena {};

    List<SourceFile> source_files {};

    struct
    {
        bool optimize = false;
        bool emit_asm = false;
        String output_filename{};
    } options;

    u32 error_count = 0;
    u32 warning_count = 0;
};

namespace globals
{
    extern BuildContext build;

    void init();
    void reset_scratch();
    void cleanup();
}

inline SourceFile* source_file_get(const FileID file_id) {
    for (usize i = 0; i < globals::build.source_files.count; i++) {
        if (globals::build.source_files[i].file_id == file_id) {
            return &globals::build.source_files[i];
        }
    }
    return nullptr;
}