/*****************************************************************************
*
*                      Higgs JavaScript Virtual Machine
*
*  This file is part of the Higgs project. The project is distributed at:
*  https://github.com/maximecb/Higgs
*
*  Copyright (c) 2012-2014, Maxime Chevalier-Boisvert. All rights reserved.
*
*  This software is licensed under the following license (Modified BSD
*  License):
*
*  Redistribution and use in source and binary forms, with or without
*  modification, are permitted provided that the following conditions are
*  met:
*   1. Redistributions of source code must retain the above copyright
*      notice, this list of conditions and the following disclaimer.
*   2. Redistributions in binary form must reproduce the above copyright
*      notice, this list of conditions and the following disclaimer in the
*      documentation and/or other materials provided with the distribution.
*   3. The name of the author may not be used to endorse or promote
*      products derived from this software without specific prior written
*      permission.
*
*  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
*  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
*  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
*  NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
*  NOT LIMITED TO PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
*  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
*  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*****************************************************************************/

module stats;

import std.stdio;
import std.datetime;
import std.string;
import std.array;
import std.stdint;
import std.conv;
import std.algorithm;
import options;

/// Program start time in milliseconds
private ulong startTimeMsecs = 0;

/// Total compilation time in microseconds
ulong compTimeUsecs = 0;

/// Total size of the machine code generated (in bytes)
ulong genCodeSize = 0;

/// Number of blocks for which there are compiled versions
ulong numBlocks = 0;

/// Number of block versions compiled
ulong numVersions = 0;

/// Maximum number of versions compiled for a block
ulong maxVersions = 0;

/// Number of blocks with specific version counts
ulong[ulong] numVerBlocks;

/// Per-instruction execution counts
ulong numCall = 0;
ulong numCallPrim = 0;
ulong numMapPropIdx = 0;

/// Number of type tests executed by test kind (dynamic)
ulong* numTypeTests[string];

/// Get a pointer to the counter variable associated with a type test
ulong* getTypeTestCtr(string testOp)
{
    // If there is no counter for this op, allocate one
    if (testOp !in numTypeTests)
        numTypeTests[testOp] = new ulong;

    // Return the counter for this test op
    return numTypeTests[testOp];
}

/// Static module constructor
shared static this()
{
    // Pre-register type test counters
    getTypeTestCtr("is_i32");
    getTypeTestCtr("is_i64");
    getTypeTestCtr("is_f64");
    getTypeTestCtr("is_const");
    getTypeTestCtr("is_refptr");
    getTypeTestCtr("is_rawptr");

    // Record the starting time
    startTimeMsecs = Clock.currAppTick().msecs();
}

/// Static module destructor, log the accumulated stats
shared static ~this()
{
    // If stats not enabled, stop
    if (opts.stats is false)
        return;

    auto endTimeMsecs = Clock.currAppTick().msecs();
    auto execTimeMsecs = endTimeMsecs - startTimeMsecs;

    writeln();
    writefln("exec time (ms): %s", execTimeMsecs);
    writefln("comp time (ms): %s", compTimeUsecs / 1000);
    writefln("code size (bytes): %s", genCodeSize);

    writefln("num blocks: %s", numBlocks);
    writefln("num versions: %s", numVersions);
    writefln("max versions: %s", maxVersions);

    writefln("num call: %s", numCall);
    writefln("num call_prim: %s", numCallPrim);
    writefln("num map_prop_idx: %s", numMapPropIdx);

    auto totalTypeTests = 0;
    foreach (testOp, pCtr; numTypeTests)
    {
        auto ctr = *pCtr;
        writefln("%s: %s", testOp, ctr);
        totalTypeTests += ctr;
    }
    writefln("type tests: %s", totalTypeTests);

    /*
    for (size_t numVers = 1; numVers <= min(opts.jit_maxvers, 100); numVers++)
    {
        auto blockCount = numVerBlocks.get(numVers, 0);
        writefln("%s versions: %s", numVers, blockCount);
    }
    */
}

