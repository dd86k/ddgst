/// Print functions.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module printers;

import ddgst;
import std.stdio;
import core.stdc.stdlib : exit;

void printHash(ubyte[] result, string filename, Hash hash, Style style)
{
    if (result == null)
        return;
    
    final switch (style) with (Style) {
    case gnu: // hash  file
        writeln(formatHex(hash, result), "  ", filename);
        break;
    case bsd: // TAG(file)= hash
        writeln(getBSDName(hash), "(", filename, ")= ", formatHex(hash, result));
        break;
    case sri: // type-hash
        writeln(getAliasName(hash), '-', formatBase64(hash, result));
        break;
    case plain: // hash
        writeln(formatHex(hash, result));
        break;
    }
}

//
// Logging
//

version (Trace) void trace(string func = __FUNCTION__, int line = __LINE__, A...)(string fmt, A args)
{
    write("TRACE:", func, ":", line, ": ");
    writefln(fmt, args);
}

void logWarn(string func = __FUNCTION__, A...)(string fmt, A args)
{
    stderr.write("warning: ");
    debug stderr.write("[", func, "] ");
    stderr.writefln(fmt, args);
}

void logError(string mod = __FUNCTION__, int line = __LINE__, A...)(int code, string fmt, A args)
{
    stderr.writef("error: (code %d) ", code);
    debug stderr.write("[", mod, ":", line, "] ");
    stderr.writefln(fmt, args);
    exit(code);
}