import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random, os

import ca_code_gen

ASSERT = True
if "NOASSERT" in os.environ:
    ASSERT = False

async def reset(dut):
    dut.reset.value = 1

    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0;

@cocotb.test()
async def test_nco(dut):
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ph_load.value = 0
    dut.ph_inc_val.value = -5

    # test a range of values

    await reset(dut)
    dut.ph_load.value = 1
    await RisingEdge(dut.clk)
    dut.ph_load.value = 0
        
    for test_count in range(1023*4):
        await RisingEdge(dut.clk)
        #if ASSERT:
        #    assert( dut.gold_code_out.value == prn_seq[chip_idx]) 
