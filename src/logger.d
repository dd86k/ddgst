/**
 * Quick and dirty logging utility.
 *
 * Authors: dd86k <dd@dax.moe>
 * Copyright: None
 * License: Public domain
 */
module logger;

import std.stdio;

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
