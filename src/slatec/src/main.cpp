#include "build_context.h"
#include "common/common.h"
#include "common/diagnostics.h"

int main(int argc, char *argv[]) {
    globals::init();
    defer { globals::cleanup(); };

    if (globals::build.error_count > 0) {
        std::fprintf(stderr, "Build failed with %u errors.\n", globals::build.error_count);
        return 1;
    }

    temp(scratch) {
        char* temp_buf = arena::allocate<char>(scratch, 1024);
        List<String> temp_tokens{};
        list::init(temp_tokens, &scratch);

        list::push(temp_tokens, {"i32"});
        list::push(temp_tokens, {"ptr"});

        for (const auto entry : temp_tokens)
        {
            printf("Temp list entry: " STR_FMT "\n", STR_ARG(entry));
        }
    });

    return 0;
}