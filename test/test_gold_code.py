import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random, os

import ca_code_gen

ASSERT = True
if "NOASSERT" in os.environ:
    ASSERT = False

async def reset(dut):
    dut.sync.value = 1

    await ClockCycles(dut.clk, 5)
    dut.sync.value = 0;

@cocotb.test()
async def test_gold_code(dut):
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    # test a range of values
    for i in range(ca_code_gen.num_sv()):
        
        prn_seq = ca_code_gen.PRN(i+1)
        prn_seq.extend(prn_seq)
        prn_seq.extend(prn_seq)

        dut.sv_taps.value = ca_code_gen.taps_from_sv(i+1)
        print("PRN IDX: " + str(i) + " Taps: " + str(hex(ca_code_gen.taps_from_sv(i+1))))
        dut.sv_load.value = 1

        await reset(dut)
        dut.sv_load.value = 0


        #check the wraparound works correctly
        for chip_idx in range(1023*4):
            await RisingEdge(dut.clk)

            if ASSERT:
                assert( dut.gold_code_out.value == prn_seq[chip_idx]) 
