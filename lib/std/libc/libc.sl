[feature(LIBC)]
module std::libc;

extern fn __errno_location() -> i32*;

extern fn printf(const u8* fmt, ...) -> i32;

extern fn open(const u8* path, i32 flags, i32 mode) -> i32;
extern fn close(i32 fd) -> i32;
extern fn read(i32 fd, void* buf, i32 count) -> i32;
extern fn write(i32 fd, void* buf, i32 count) -> i32;
extern fn lseek(i32 fd, i32 offset, i32 whence) -> i32;

extern fn malloc(i32 size) -> void*;
extern fn realloc(void* ptr, i32 size) -> void*;
extern fn memcpy(void* dst, void* src, i32 len) -> void*;
extern fn memset(void* dst, i32 value, i32 len) -> void*;
extern fn memcmp(void* first, void* second) -> i32;
extern fn free(void* data);

extern fn abort();
extern fn exit(i32 code);
