/// Check list reader.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module reader;

import std.format : formattedRead;

/// Read a formatted GNU tag line.
/// Throws: Nothing.
/// Params:
///     line = Full GNU formatted tag string
///     hash = Hexadecimal hash string (e.g., "aabbccdd")
///     file = File string (e.g., "nightly.iso")
/// Returns: True on success.
bool readGNULine(string line, ref string hash, ref string file)
{
    // Tested to work with one or many spaces
    try
    {
        bool r = formattedRead(line, "%s %s", hash, file) == 2;
        
        // Binary indicator
        if (r && file[0] == '*')
            file = file[1..$];
        
        return r;
    }
    catch (Exception)
    {
        return false;
    }
}
unittest
{
    string hash, file;
    assert(readGNULine(
	"f6067df486cbdbb0aac026b799b26261c92734a3  LICENSE", hash, file));
    assert(hash == "f6067df486cbdbb0aac026b799b26261c92734a3");
    assert(file == "LICENSE");
}

/// Read a formatted BSD tag line.
/// Throws: Nothing.
/// Params:
///     line = Full BSD formatted tag string
///     type = Hash type string (e.g., "SHA256")
///     file = File string (e.g., "nightly.iso")
///     hash = Hexadecimal hash string (e.g., "8080aabb")
/// Returns: True on success.
bool readBSDLine(string line,
    ref string type, ref string file, ref string hash)
{
    try // Tested to work with and without spaces
        return formattedRead(line, "%s (%s) = %s", type, file, hash) == 3;
    catch (Exception)
        return false;
}
unittest
{
    string type, file, hash;
    assert(readBSDLine(
	"SHA256 (Fedora-Workstation-Live-x86_64-36-1.5.iso) = " ~
        "80169891cb10c679cdc31dc035dab9aae3e874395adc5229f0fe5cfcc111cc8c",
	type, file, hash));
    assert(type == "SHA256");
    assert(file == "Fedora-Workstation-Live-x86_64-36-1.5.iso");
    assert(hash == "80169891cb10c679cdc31dc035dab9aae3e874395adc5229f0fe5cfcc111cc8c");
}

/// Read a formatted SRI tag line.
/// Throws: Nothing.
/// Params:
///     line = Full RSI formatted tag string
///     type = Hash type string (e.g., "md5")
///     hash = Base64 hash string (e.g., "OFPip4okcUW0qhZmdzb23g==")
/// Returns: True on success.
bool readSRILine(string line, ref string type, ref string hash)
{
    try
        return formattedRead(line, "%s-%s", type, hash) == 2;
    catch (Exception)
        return false;
}
unittest
{
    string type, hash;
    assert(readSRILine("sha1-9gZ99IbL27CqwCa3mbJiYcknNKM=", type, hash));
    assert(type == "sha1");
    assert(hash == "9gZ99IbL27CqwCa3mbJiYcknNKM=");
}