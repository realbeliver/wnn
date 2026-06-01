import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random, os
import numpy as np

SPI_PERIOD_NS = 1000

ASSERT = True
if "NOASSERT" in os.environ:
    ASSERT = False

async def reset(dut):
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0;

async def spi_operation(dut, delay_ns=2000, word_to_send=0x81A50F00):
    dut.spi_dom_csn.value = 1;
    dut.spi_dom_mosi.value = 1;
    dut.spi_dom_clk.value = 0;

    await Timer(delay_ns, units='ns')
    dut.spi_dom_csn.value = 0;
    dut.spi_dom_mosi.value = (word_to_send >> 31) & 1
    await Timer(1.5*SPI_PERIOD_NS, units='ns')
    for i in range(31):
        #set the bit
        await Timer(SPI_PERIOD_NS/2, units='ns')
        dut.spi_dom_clk.value = 1
        await Timer(SPI_PERIOD_NS/2, units='ns')
        dut.spi_dom_clk.value = 0
        dut.spi_dom_mosi.value = (word_to_send >> 31-i-1) & 1;
    await Timer(1.5*SPI_PERIOD_NS, units='ns')
    dut.spi_dom_csn.value = 1;

@cocotb.test()
async def test_control_system(dut):
    clock = Clock(dut.clk, int((1/4.092)*1000000), units="ps")
    cocotb.start_soon(clock.start())
    spi_task = cocotb.start_soon(spi_operation(dut))
    # test a range of values
    dut.spi_dom_csn.value = 1;
    dut.spi_dom_mosi.value = 1;
    dut.spi_dom_clk.value = 0;

    dut.time_pulse.value = 0;

    
    
    await reset(dut)
    await RisingEdge(dut.clk)
    dut.acq_begin.value = 1
    await RisingEdge(dut.clk)
    dut.acq_begin.value = 0


    for test_count in range(1023):
        await RisingEdge(dut.clk)
        
        #if ASSERT:
        #    assert( dut.gold_code_out.value == prn_seq[chip_idx]) 
