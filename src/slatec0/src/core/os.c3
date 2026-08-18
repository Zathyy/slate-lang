module slate::core::os;

import std::math;

fn OsType current()
{
	return env::OS_TYPE;
}

fn bool is_apple(OsType os)
{
	switch (os)
	{
		case MACOS:
		case TVOS:
		case WATCHOS:
		case IOS:
			return true;
		default:
			return false;
	}
}

<*
 @return "Alignment in bytes"
*>
fn AlignData get_alignment(OsType os, ArchType arch, uint bits)
{
	uint bytes = bits / 8;

	switch (arch)
	{
		case X86_64:
			return { bytes, bytes };
		default:
			break;
	}

	unreachable("Unknown Arch");
}
