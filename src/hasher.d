/**
 * Where data gets processed, called from main.
 *
 * Authors: dd86k <dd@dax.moe>
 * Copyright: None
 * License: Public domain
 */
module hasher;

import std.stdio, std.mmfile;
import ddh.ddh;

private enum DEFAULT_CHUNK_SIZE = 64 * 1024; // Seemed the best in benchmarks at least

/// Abstraction layer between CLI (config) and DDH (processing)
struct Hasher
{
	DDH_T ddh;
	int delegate(string path) process;
	char[] hash;
	ulong inputSize; /// Buffer size
	bool fileText;
	Exception lastException;
	
	//
	// ANCHOR: Configuration
	//
	
	this(DDHType type)
	{
		ddh_init(ddh, type);
		process = &processFile;
		inputSize = DEFAULT_CHUNK_SIZE;
		fileText = false;
	}
	
	void setModeFile()
	{
		process = &processFile;
	}
	
	void setModeMmFile()
	{
		process = &processMmfile;
	}
	
	//
	// ANCHOR: Process functions
	//
	
	int processFile(string path)
	{
		try
		{
			File f;	// Must never be void
			// BUG: Using opAssign with LDC2 crashes at runtime
			f.open(path, fileText ? "r" : "rb");
			ulong flen = f.size();
			
			if (flen)
			{
				foreach (ubyte[] chunk; f.byChunk(inputSize))
					ddh_compute(ddh, chunk);
			}
			
			f.close();
			hash = ddh_string(ddh);
			ddh_reset(ddh);
			return 0;
		}
		catch (Exception ex)
		{
			lastException = ex;
			return 1;
		}
	}
	
	int processMmfile(string path)
	{
		import std.typecons : scoped;
		
		try
		{
			auto f = scoped!MmFile(path);
			ulong flen = f.length;
			
			if (flen)
			{
				ulong start;
				
				if (flen > inputSize)
				{
					const ulong climit = flen - inputSize;
					for (; start < climit; start += inputSize)
						ddh_compute(ddh, cast(ubyte[])f[start..start + inputSize]);
				}
				
				// Compute remaining
				ddh_compute(ddh, cast(ubyte[])f[start..flen]);
			}
			
			hash = ddh_string(ddh);
			ddh_reset(ddh);
			return 0;
		}
		catch (Exception ex)
		{
			lastException = ex;
			return 1;
		}
	}

	int processText(string text)
	{
		try
		{
			ddh_compute(ddh, cast(ubyte[])text);
			hash = ddh_string(ddh);
			ddh_reset(ddh);
			return 0;
		}
		catch (Exception ex)
		{
			lastException = ex;
			return 1;
		}
	}

	int processStdin()
	{
		try
		{
			foreach (ubyte[] chunk; stdin.byChunk(inputSize))
				ddh_compute(ddh, chunk);
			hash = ddh_string(ddh);
			ddh_reset(ddh);
			return 0;
		}
		catch (Exception ex)
		{
			lastException = ex;
			return 1;
		}
	}
}
