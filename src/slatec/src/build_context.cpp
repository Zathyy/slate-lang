#include "build_context.h"

namespace globals {
    BuildContext build = {};

    void init() {
        arena::init(&build.permanent_arena, 64 * 1024);
        arena::init(&build.scratch_arena, 64 * 1024);

        list::init(build.source_files, &build.permanent_arena);

        build.error_count = 0;
        build.warning_count = 0;
    }

    void reset_scratch() {
        arena::reset(&build.scratch_arena);
    }

    void cleanup() {
        arena::free(&build.permanent_arena);
        arena::free(&build.scratch_arena);
        build = {};
    }
}