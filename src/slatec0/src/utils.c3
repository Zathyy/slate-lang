module slate::utils;

import std::os::win32;

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
