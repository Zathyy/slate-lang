module slate::utils;
import slate::core;

import std::os::win32;
import std::os::env;
import std::os::process;
import std::collections;
import std::io;

fn String get_executable_path()
{
	$switch:
	$case env::WIN32:
		Win32_DWORD capacity = 260;
		WString buffer = (WString)mem::malloc(Char16::size * capacity);

		while (buffer != null)
		{
			Win32_DWORD len = win32::getModuleFileNameW(null, buffer, capacity);
			if (len == 0)
			{
	            mem::free(buffer);
	            return "";
        	}

	        if (len < capacity && win32::getLastError() != win32::ERROR_INSUFFICIENT_BUFFER)
	        {
	        	String ret_str = string::from_wstring(mem, buffer)!!;
				mem::free(buffer);
				return ret_str;
	        }

	        capacity *= 2;
	        WString new_buffer = (WString)mem::realloc(buffer, capacity);
			if (!new_buffer)
			{
				mem::free(buffer);
				return "";
			}
			buffer = new_buffer;
		}

		return "";

	$endswitch
}

fn String get_sdk_dir(Allocator alloc)
{
	String app_data = env::get_var(tmem, "LOCALAPPDATA")!!;
    return string::format(alloc, "%s\\slate\\sdk", app_data);
}

fn String get_msvc_sdk(Allocator alloc) => @pool()
{
	String sdk_dir = string::format(alloc, "%s\\msvc", get_sdk_dir(tmem));

	if (file::exists(sdk_dir))
    {
        return sdk_dir;
    }

	path::mkdir(sdk_dir, true)!!;

	List{String} sb; sb.tinit();
	sb.push("python");
	sb.push(string::tformat("%s/scripts/portable-msvc.py", globals::root_path));
	sb.push("--accept-license");
	sb.push("--output");
	sb.push(sdk_dir);

	diagnostics::log_info("[SDK]: Downloading portable MSVC SDK to %s...", sdk_dir);

	Process proc = process::spawn(sb.array_view(), INHERIT_ENV | INHERIT_STDIO)!!;
	defer (void)proc.destroy();
	proc.join()!!;

	return sdk_dir;
}
