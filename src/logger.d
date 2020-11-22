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

/*void fatal(string mod = __MODULE__, uint line = __LINE__, Args...)(string fmt, Args args)
{
	import core.stdc.stdlib : exit;
	debug stderr.writef("[%s:%u] fatal: ", mod, line);
	else  stderr.write("fatal: ");
	stderr.writefln(fmt, args);
	exit(255);
}*/

void error(string mod = __MODULE__, uint line = __LINE__, Args...)(string fmt, Args args)
{
	debug stderr.writef("[%s:%u] error: ", mod, line);
	else  stderr.write("error: ");
	stderr.writefln(fmt, args);
}

void warn(Args...)(string fmt, Args args)
{
	stderr.write("warning: ");
	stderr.writefln(fmt, args);
}
