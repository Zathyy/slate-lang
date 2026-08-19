module std::core::env;

enum TargetOS : u8
{
    Win32,
}

enum TargetArch : u8
{
    X86_64,
}

const TargetOS TARGET_OS = $$TARGET_OS;
const TargetArch TARGET_ARCH = $$TARGET_ARCH;

//const bool TESTING = $$TESTING;
