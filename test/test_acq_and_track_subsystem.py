import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random, os
import numpy as np

import gen_synthetic_data
import ca_code_gen

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
async def test_acq_and_track_subsystem(dut):
    clock = Clock(dut.clk, int((1/4.092)*1000000), units="ps")
    cocotb.start_soon(clock.start())

    # test a range of values

    test_data_unquantised = gen_synthetic_data.generate_synthetic_data()
    i_chan_quantised = np.array(np.where(np.real(test_data_unquantised) >= 0.0, 1,-1),dtype="int8")
    q_chan_quantised = np.array(np.where(np.imag(test_data_unquantised) >= 0.0, 1,-1),dtype="int8")

    dut.sv_test_taps.value = ca_code_gen.taps_from_sv(1)
    dut.i_chan.value = 0
    dut.q_chan.value = 0

    dut.acq_begin.value = 0

    dut.phase_inc_start.value = 0
    dut.phase_inc_step.value = 0
    dut.phase_inc_count.value = 0
    
    await reset(dut)
    await RisingEdge(dut.clk)
    dut.acq_begin.value = 1
    await RisingEdge(dut.clk)
    dut.acq_begin.value = 0


    for test_count in range(1023*4*1028):
        await RisingEdge(dut.clk)
        if(i_chan_quantised[test_count] == 1):
            dut.i_chan.value = 1
        else:
            dut.i_chan.value = 0

        if(q_chan_quantised[test_count] == 1):
            dut.q_chan.value = 1
        else:
            dut.q_chan.value = 0
        
        
        #if ASSERT:
        #    assert( dut.gold_code_out.value == prn_seq[chip_idx]) 
