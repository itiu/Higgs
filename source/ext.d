module ext;

import core.memory;
import std.c.math;
import std.stdio;
import std.string;
import std.array;
import std.stdint;
import std.conv;
import std.algorithm;
import std.traits;
import std.datetime;
import options;
import stats;
import parser.parser;
import ir.ir;
import ir.ops;
import ir.ast;
import runtime.vm;
import runtime.layout;
import runtime.object;
import runtime.string;
import runtime.gc;
import jit.codeblock;
import jit.x86;
import jit.util;
import jit.jit;
import core.sys.posix.dlfcn;
import std.concurrency;

void gen_send_2str_recieve_1str(
    BlockVersion ver,
    CodeGenState st,
    IRInstr instr,
    CodeBlock as
)
{
    auto vm = st.callCtx.vm;

    extern (C) refptr getStr(CallCtx callCtx, refptr tidName, refptr strPtr1, refptr strPtr2)
    {
        auto str_tid_name = extractStr(tidName);
	Tid to_tid = locate(str_tid_name); 

        auto vm = callCtx.vm;
        vm.setCallCtx(callCtx);

	string res;
	if (to_tid != Tid.init)
	{	
    	    auto str1 = extractStr(strPtr1);
    	    auto str2 = extractStr(strPtr2);
	    send (to_tid, str1, str2, thisTid);

	    receiveTimeout(dur!"seconds"(1),
		(string msg) 
		{ 
		    //writeln("JS Received.", msg);
		    res = msg; 
		},
		(Variant v) 
		{ 
		    writeln("Received some other type."); 
		}
	    );
	}

	auto strObj = getString(vm, to!wstring(res));

        vm.setCallCtx(null);

        return strObj;
    }

    // Get the string pointer
    auto opnd0 = st.getWordOpnd(as, instr, 0, 64, X86Opnd.NONE, true, false);
    auto opnd1 = st.getWordOpnd(as, instr, 1, 64, X86Opnd.NONE, true, false);
    auto opnd2 = st.getWordOpnd(as, instr, 2, 64, X86Opnd.NONE, true, false);

    // TODO: spill regs, may GC

    // Allocate the output operand
    auto outOpnd = st.getOutOpnd(as, instr, 64);

    as.pushJITRegs();

    // Call the fallback implementation
    as.ptr(cargRegs[0], st.callCtx);
    as.mov(cargRegs[1].opnd, opnd0);
    as.mov(cargRegs[2].opnd, opnd1);
    as.mov(cargRegs[3].opnd, opnd2);
    as.ptr(scrRegs[0], &getStr);
    as.call(scrRegs[0]);

    as.popJITRegs();

    // Store the output value into the output operand
    as.mov(outOpnd, X86Opnd(RAX));

    // The output is a reference pointer
    st.setOutType(as, instr, Type.STRING);
}

/// Print a string to standard output
Opcode SEND_2STR_RECIEVE_1STR = { "send_2str_recieve_1str", true, [OpArg.LOCAL, OpArg.LOCAL, OpArg.LOCAL], &gen_send_2str_recieve_1str, OpInfo.MAY_GC };
