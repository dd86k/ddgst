module logger;

import std.stdio;

/+
version (Windows)
{
	private __gshared HANDLE g_win_stdout;
}

private __gshared bool g_color_enabled;

void prep()
{
	version (Windows)
	{
		g_win_stdout = GetStdHandle(STD_ERROR_HANDLE);
	}
}

void colors(bool enable)
{
	g_color_enabled = enable;
}
+/

void error(string mod = __MODULE__, uint line = __LINE__, Args...)(string fmt, Args args)
{
	debug stderr.writef(mod~"@L%u: ", line);
	else  stderr.write(mod~": ");
	stderr.writefln(fmt, args);
}
