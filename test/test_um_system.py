import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer, Edge
import random, os


import numpy as np

import gen_synthetic_data
import ca_code_gen

SPI_PERIOD_NS = 1000
TRACKING_THRESHOLD = 5000
#TRACKING_THRESHOLD = 100000

TRACKING_LOOP_PERIOD = 10
NUM_TRACK_CHANNELS = 3
TRACKING_CONTROL_ADDR = 9
TRACKING_BASE_ADDR = 10
TRACKING_CHAN_STRIDE = 6
TRACKING_CONFIG_STRIDE = 4

num_svs = 0
sv_array = np.zeros(num_svs)
target_snr_db_array = np.zeros(num_svs)
code_phase_error_array = np.zeros(num_svs)
freq_error_hz_array = np.zeros(num_svs)
num_tracking = 0
tracking_time = np.zeros(NUM_TRACK_CHANNELS)
tracking_pow = np.zeros(NUM_TRACK_CHANNELS)
tracking_ph_inc = np.zeros(NUM_TRACK_CHANNELS)

ASSERT = True
if "NOASSERT" in os.environ:
    ASSERT = False

GATE = False
if "GATES" in os.environ:
    GATE = True

async def reset(dut):
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1;

async def spi_transaction(dut, word_to_send, delay_ns=5000):
    read_op_val = 0x00000000
    await Timer(delay_ns, unit='ns')
    uin_val = 0x02

    #print("Sending: "+ str(hex(word_to_send[j])))

    if(((word_to_send >> 31) & 1) == 1):
        uin_val = uin_val | (1 << 1)
    else:
        uin_val = uin_val & 0xFD

    dut.uio_in.value = uin_val

    await Timer(1.5*SPI_PERIOD_NS, unit='ns')
    for i in range(31):
    #     #set the bit
        await Timer(SPI_PERIOD_NS/2, unit='ns')
        uin_val = uin_val | (1 << 3)
        dut.uio_in.value = uin_val
        read_op_val = (read_op_val << 1) | ((int(dut.uio_out.value) >> 2) & 0x01)
        await Timer(SPI_PERIOD_NS/2, unit='ns')
        uin_val = uin_val & 0xF7

        if(((word_to_send >> 31-i-1) & 1) == 1):
            uin_val = uin_val | (1 << 1)
        else:
            uin_val = uin_val & 0xFD

        dut.uio_in.value = uin_val

    await Timer(1.5*SPI_PERIOD_NS, unit='ns')
    uin_val = uin_val | 0x01
    dut.uio_in.value = uin_val
    return read_op_val
    

async def spi_operation(dut, num_transactions=1,delay_ns=2000, word_to_send=0x81A50F00, num_read_ops=5, read_op_delays=[5000,5000,5000,5000,5000], read_op_words=[0x00000000, 0x05000000, 0x06000000, 0x07000000, 0x08000000], tracking_assignment_delay = 5000):
    global num_svs
    global num_tracking

    tracking_loop_counter = 0
    
    uin_val = 0x03
    dut.uio_in.value = uin_val
    #starting transactions, initialise and setup system
    for j in range(num_transactions):
        read_op_val = await spi_transaction(dut, word_to_send[j], delay_ns=delay_ns[j])
        
    #running transactions
    pow_result_array = np.zeros(1023)
    while True:
        await dut.uo_out.value_change
        #await Edge(dut.uo_out)
        
        readback_idx = 0
        readback_ph_step = 0
        readback_ival = 0
        readback_qval = 0
        readback_magsq = 0

        tracking_results = np.zeros((6,NUM_TRACK_CHANNELS))
        new_timings = np.zeros(NUM_TRACK_CHANNELS, dtype='int32')

        for j in range(num_read_ops):
            if(num_tracking != 0):
                if(tracking_loop_counter < TRACKING_LOOP_PERIOD):
                    tracking_loop_counter = tracking_loop_counter + 1
                else:
                    tracking_loop_counter = 0
                    for track_chan_idx in range(num_tracking):
                        for emlcomplex in range(3*2):
                            tracking_addr = TRACKING_BASE_ADDR + (track_chan_idx*TRACKING_CHAN_STRIDE) + emlcomplex
                            tracking_transaction = ((tracking_addr & 0x000000FF) << 24) #read operation
                            tracking_op_val = await spi_transaction(dut, tracking_transaction, delay_ns=tracking_assignment_delay)
                            tracking_results[emlcomplex][track_chan_idx] = int.from_bytes(((tracking_op_val & 0x00000FFF)<<4).to_bytes(2),signed=True)/16
                        #evaluate eml here
                        early_pow = tracking_results[0][track_chan_idx]*tracking_results[0][track_chan_idx] + tracking_results[1][track_chan_idx]*tracking_results[1][track_chan_idx]
                        mid_pow = tracking_results[2][track_chan_idx]*tracking_results[2][track_chan_idx] + tracking_results[3][track_chan_idx]*tracking_results[3][track_chan_idx]
                        late_pow = tracking_results[4][track_chan_idx]*tracking_results[4][track_chan_idx] + tracking_results[5][track_chan_idx]*tracking_results[5][track_chan_idx]
                        #print(f"E I: {tracking_results[0][track_chan_idx]} E Q: {tracking_results[1][track_chan_idx]} /M I: {tracking_results[2][track_chan_idx]} M Q: {tracking_results[3][track_chan_idx]} /L I: {tracking_results[4][track_chan_idx]}  L Q: {tracking_results[5][track_chan_idx]} ")
                        if((early_pow > mid_pow) and (mid_pow > late_pow)):
                            new_timings[track_chan_idx] = tracking_time[track_chan_idx]-1
                            print(f"Early Power greater than mid power and late power, retarding timing old {tracking_time[track_chan_idx]} new timing {new_timings[track_chan_idx]}")
                        else:
                            if((late_pow > mid_pow) and (mid_pow > early_pow)):
                                new_timings[track_chan_idx] = tracking_time[track_chan_idx]+1
                                print(f"late Power greater than mid power and early power, advancing timing old {tracking_time[track_chan_idx]} new timing {new_timings[track_chan_idx]}")

            read_op_val = await spi_transaction(dut, read_op_words[j], delay_ns=read_op_delays[j])
        
            if(read_op_words[j] == 0x05000000):
                readback_ival = int.from_bytes(((read_op_val & 0x00000FFF)<<4).to_bytes(2),signed=True)/16
            elif(read_op_words[j] == 0x06000000):
                readback_qval = int.from_bytes(((read_op_val & 0x00000FFF)<<4).to_bytes(2),signed=True)/16
            elif(read_op_words[j] == 0x07000000):
                readback_ph_step = read_op_val
            else:
                #it was the last one. check the results.
                readback_magsq = readback_ival*readback_ival + readback_qval*readback_qval
                readback_idx = int(read_op_val & 0x000003FF)
                pow_result_array[readback_idx] = readback_magsq
                if(readback_magsq >= TRACKING_THRESHOLD):
                    #setup tracking channel here
                    if(num_tracking < NUM_TRACK_CHANNELS):
                        tracking_pow[num_tracking] = readback_magsq
                        tracking_time[num_tracking] = readback_idx << 2
                        tracking_channel_idx = num_tracking
                        num_tracking = num_tracking+1
                        print(f"New tracking assignment time {readback_idx} power {readback_magsq} now tracking {num_tracking}")
                    else:
                        min_idx = np.argmin(tracking_pow)
                        tracking_channel_idx = min_idx
                        print(f"Retuning tracker {min_idx} for time {readback_idx} power {readback_magsq}")
                        tracking_pow[min_idx] = readback_magsq
                        tracking_time[min_idx] = readback_idx << 2

                    #do tracking setup transactions here
                    tracking_addr = TRACKING_BASE_ADDR + tracking_channel_idx*TRACKING_CHAN_STRIDE
                    tracking_transaction = ((tracking_addr & 0x000000FF) << 24) | 0x80000000
                    #8 for the integer part, tracking can be done in subsample accuracy, shif by 2 more to handle that
                    tracking_transaction = tracking_transaction | readback_idx << (8+2)
                    print(f"Time write operation {hex(tracking_transaction)}")
                    read_op_val = await spi_transaction(dut, tracking_transaction, delay_ns=tracking_assignment_delay)

                    tracking_addr = TRACKING_BASE_ADDR + (tracking_channel_idx*TRACKING_CHAN_STRIDE) + 1
                    tracking_transaction = ((tracking_addr & 0x000000FF) << 24) | 0x80000000
                    tracking_transaction = tracking_transaction | ((readback_ph_step << 8) & 0x00FFFF00)

                    print(f"Freq write operation {hex(tracking_transaction)}")
                    read_op_val = await spi_transaction(dut, tracking_transaction, delay_ns=tracking_assignment_delay)


                    tracking_addr = TRACKING_BASE_ADDR + (tracking_channel_idx*TRACKING_CHAN_STRIDE) + 2
                    tracking_transaction = ((tracking_addr & 0x000000FF) << 24) | 0x80000000
                    tracking_transaction = tracking_transaction | (word_to_send[0] & 0x00FFFF00)

                    print(f"SV write operation {hex(tracking_transaction)}")
                    read_op_val = await spi_transaction(dut, tracking_transaction, delay_ns=tracking_assignment_delay)

                    tracking_addr = TRACKING_CONTROL_ADDR
                    tracking_transaction = ((tracking_addr & 0x000000FF) << 24) | 0x80000000
                    #enable and update this channel
                    tracking_transaction = tracking_transaction | (0x3 << (tracking_channel_idx*TRACKING_CONFIG_STRIDE)+8) & 0x00FFFF00

                    print(f"Tracking Control Update operation {hex(tracking_transaction)}")
                    read_op_val = await spi_transaction(dut, tracking_transaction, delay_ns=tracking_assignment_delay)

                if(readback_idx == 1022):
                    top_five_locations = np.argpartition(pow_result_array, -5)[-5:]
                    top_five_values = pow_result_array[top_five_locations]
                    print(f"At end of acq pass, top 5 maxes are at: {top_five_locations} values {top_five_values}")

                    #clear it ready for next iteration
                    pow_result_array = np.zeros(1023)

        for chan_idx in range(num_tracking):
            if(new_timings[chan_idx] != 0):
                tracking_time[chan_idx] = new_timings[chan_idx]
                tracking_addr = TRACKING_BASE_ADDR + tracking_channel_idx*TRACKING_CHAN_STRIDE
                tracking_transaction = ((tracking_addr & 0x000000FF) << 24) | 0x80000000
                #8 for the integer part, tracking can be done in subsample accuracy, shif by 2 more to handle that
                tracking_transaction = tracking_transaction | int(new_timings[chan_idx]) << (8)
                read_op_val = await spi_transaction(dut, tracking_transaction, delay_ns=tracking_assignment_delay)
                tracking_addr = TRACKING_CONTROL_ADDR
                tracking_transaction = ((tracking_addr & 0x000000FF) << 24) | 0x80000000
                #enable and update this channel
                tracking_transaction = tracking_transaction | (0x3 << (tracking_channel_idx*TRACKING_CONFIG_STRIDE)+8) & 0x00FFFF00
                read_op_val = await spi_transaction(dut, tracking_transaction, delay_ns=tracking_assignment_delay)
                print(f"Upated timing for channel: {chan_idx}")


        #deassert the interrrupt
        read_op_val = await spi_transaction(dut, 0x80000100, delay_ns=read_op_delays[0])
            




@cocotb.test()
async def test_um_system(dut):
    
    if GATE:
        num_svs_range = [1, 1]
        snr_range_db = [-10, -20]
        code_phase_error_range = [0, 1023];
        freq_error_range_hz = [0, 0];
        sv_search_range = [1, 1]
        test_samples = 1023*4*1028
    else:
        num_svs_range = [1, 1]
        snr_range_db = [-10, -20]
        code_phase_error_range = [0, 1023];
        freq_error_range_hz = [-1000, 1000];
        sv_search_range = [1, 1]
        test_samples = 1023*4*5*1028



    # test a range of values
    (test_data_unquantised, num_svs, sv_array, target_snr_db_array, code_phase_error_array, freq_error_hz_array) = gen_synthetic_data.generate_synthetic_data(num_svs_range=num_svs_range, snr_range_db=snr_range_db, code_phase_error_range=code_phase_error_range, freq_error_range_hz=freq_error_range_hz, sv_search_range=sv_search_range)

    i_chan_quantised = np.array(np.where(np.real(test_data_unquantised) >= 0.0, 1,-1),dtype="int8")
    q_chan_quantised = np.array(np.where(np.imag(test_data_unquantised) >= 0.0, 1,-1),dtype="int8")

    taps = ca_code_gen.taps_from_sv(1)
    #print(hex(taps))

    delays = [5000, 5000, 5000, 5000, 5000]
    transactions = [ 0x81000000 | (taps << 8), 0x8200F600, 0x83000500, 0x84000500, 0x80000200]

    clock = Clock(dut.clk, int(((1/4.092)*1000000)/2)*2, unit="ps") #force divisible by two
    cocotb.start_soon(clock.start())
    spi_task = cocotb.start_soon(spi_operation(dut, num_transactions=5, delay_ns=delays, word_to_send=transactions))


    dut.ena.value = 1
    dut.ui_in.value = 0
    # test a range of values



    # test a range of values

    await reset(dut)
    await RisingEdge(dut.clk)
        
    for test_count in range(test_samples):

        await RisingEdge(dut.clk)
        uin_val = 0x00
        if(i_chan_quantised[test_count] == 1):
            uin_val = 1
      
        if(q_chan_quantised[test_count] == 1):
            uin_val = uin_val | (1 << 2)

        dut.ui_in.value = uin_val
        
        #if ASSERT:
        #    assert( dut.gold_code_out.value == prn_seq[chip_idx]) 
