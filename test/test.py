import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import math
import random

# -----------------------------------------------------------------------------
# Helper Functions: Math & Q8.8 Conversions
# -----------------------------------------------------------------------------
def real_to_q8p8(val):
    """Convert a Python float to a 16-bit Q8.8 integer (two's complement)."""
    t = val * 256.0
    if t > 32767.0: return 0x7FFF
    if t < -32768.0: return 0x8000
    return int(t) & 0xFFFF

def q8p8_to_real(val):
    """Convert a 16-bit Q8.8 integer back to a Python float."""
    if val >= 0x8000:
        val -= 0x10000
    return val / 256.0

def neuron_golden(x, w, t, d):
    """Golden model calculation for the WNN neuron."""
    if abs(d) < 1e-9: 
        return 0.0
    z = (x - t) / d
    ev = math.exp(-0.5 * z * z)
    return w * z * ev

def saturate_q8p8(val):
    """Saturate a real golden value to the Q8.8 representable range."""
    if val > 127.99609375: return 127.99609375
    if val < -128.0:       return -128.0
    return val

def sum_golden(x, w, t, d):
    """Calculates the saturated golden sum for a single neuron."""
    return saturate_q8p8(neuron_golden(x, w, t, d))

# -----------------------------------------------------------------------------
# Hardware Interaction Coroutines
# -----------------------------------------------------------------------------
def set_ui_in(dut, cfg_s=0, cfg_v=0, cfg_l=0, cfg_p=0, x_s=0, x_v=0):
    """Packs the individual control signals into the 8-bit ui_in bus."""
    val = (x_v << 6) | (x_s << 5) | (cfg_p << 3) | (cfg_l << 2) | (cfg_v << 1) | cfg_s
    dut.ui_in.value = val

async def send_cfg_word(dut, data_16):
    """Shifts 16 bits of configuration data serially (LSB first)."""
    for i in range(16):
        bit = (data_16 >> i) & 1
        set_ui_in(dut, cfg_s=bit, cfg_v=1)
        await RisingEdge(dut.clk)
    set_ui_in(dut, cfg_s=0, cfg_v=0)
    await RisingEdge(dut.clk)

async def load_cfg_param(dut, param, value):
    """Sends a config word and pulses the load signal for a specific parameter."""
    await send_cfg_word(dut, value)
    set_ui_in(dut, cfg_p=param, cfg_l=1)
    await RisingEdge(dut.clk)
    set_ui_in(dut, cfg_p=0, cfg_l=0)
    await RisingEdge(dut.clk)

async def load_neuron(dut, w, t, d):
    """Loads w, t, and d parameters into the hardware."""
    await load_cfg_param(dut, 0, real_to_q8p8(w))
    await load_cfg_param(dut, 1, real_to_q8p8(t))
    await load_cfg_param(dut, 2, real_to_q8p8(d))

async def send_x(dut, data_16):
    """Waits for hardware ready, then shifts 16 bits of input x (LSB first)."""
    # Wait until ready bit (uo_out[2]) goes high
    while not (dut.uo_out.value.integer & 0x04):
        await RisingEdge(dut.clk)

    for i in range(16):
        bit = (data_16 >> i) & 1
        set_ui_in(dut, x_s=bit, x_v=1)
        await RisingEdge(dut.clk)
    set_ui_in(dut, x_v=0)

async def capture_sum(dut):
    """Waits for sum_valid, then captures 16 bits of output sum (LSB first)."""
    # Wait until sum_valid bit (uo_out[1]) goes high
    while not (dut.uo_out.value.integer & 0x02):
        await RisingEdge(dut.clk)

    data = 0
    # Capture bit 0 on the same cycle valid goes high
    data |= (dut.uo_out.value.integer & 0x01)
    for i in range(1, 16):
        await RisingEdge(dut.clk)
        bit = (dut.uo_out.value.integer & 0x01)
        data |= (bit << i)
    return data

# -----------------------------------------------------------------------------
# Concurrent Assertion Monitor
# -----------------------------------------------------------------------------
async def monitor_assertions(dut):
    """Background task to continuously monitor concurrent assertions."""
    while True:
        await RisingEdge(dut.clk)
        if dut.rst_n.value == 1:
            ready = (dut.uo_out.value.integer & 0x04) != 0
            sum_valid = (dut.uo_out.value.integer & 0x02) != 0
            
            # Using try/except in case internal signals are optimized away in gate-level sims
            try:
                x_latch_valid = dut.x_latch_valid.value
                shift_active = dut.shift_active.value
                busy_counter = dut.busy_counter.value
                sum_bit_cnt = dut.sum_bit_cnt.value
                x_bit_cnt = dut.x_bit_cnt.value

                # A: ready and x_latch_valid must never overlap
                if ready and x_latch_valid:
                    dut._log.error(f"Error: [ASSERT A] ready & x_latch_valid both high at {cocotb.utils.get_sim_time('ns')} ns")
                
                # B: sum_valid must equal shift_active
                if sum_valid and not shift_active:
                    dut._log.error(f"Error: [ASSERT B] sum_valid high but shift_active low at {cocotb.utils.get_sim_time('ns')} ns")
                
                # C: ready must imply pipeline not busy (busy_counter is 5-bit)
                if ready and busy_counter != 0:
                    dut._log.error(f"Error: [ASSERT C] ready high but busy_counter is non-zero at {cocotb.utils.get_sim_time('ns')} ns")

                # D: ready must imply output serialiser idle
                if ready and shift_active:
                    dut._log.error(f"Error: [ASSERT D] ready & shift_active both high at {cocotb.utils.get_sim_time('ns')} ns")
                
                # E: sum_bit_cnt stays in [0,15]
                if sum_bit_cnt > 15:
                    dut._log.error(f"Error: [ASSERT E] sum_bit_cnt > 15 at {cocotb.utils.get_sim_time('ns')} ns")
                
                # F: x_bit_cnt stays in [0,15]
                if x_bit_cnt > 15:
                    dut._log.error(f"Error: [ASSERT F] x_bit_cnt > 15 at {cocotb.utils.get_sim_time('ns')} ns")
            
            except AttributeError:
                # Internal signals not accessible; standard for black-box testing
                pass

# -----------------------------------------------------------------------------
# Main Test Definition
# -----------------------------------------------------------------------------
@cocotb.test(timeout_time=50, timeout_unit="ms")
async def test_wnn_comprehensive(dut):
    # Start the clock (10 ns period -> 100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Start the assertion monitor
    cocotb.start_soon(monitor_assertions(dut))

    # Testbench State
    pass_count = 0
    fail_count = 0
    test_num = 1
    w_curr, t_curr, d_curr = 0.0, 0.0, 0.0

    async def run_test(x_real, grp):
        """Helper to run a single test vector, verify it, and log the result."""
        nonlocal pass_count, fail_count, test_num
        
        x_q88 = real_to_q8p8(x_real)
        gld = sum_golden(x_real, w_curr, t_curr, d_curr)
        
        # 8% relative + 0.15 absolute floor
        tol = abs(gld) * 0.08 + 0.15 

        # Hardware interaction
        await send_x(dut, x_q88)
        hw_raw = await capture_sum(dut)
        hw_real = q8p8_to_real(hw_raw)

        diff = abs(hw_real - gld)

        # Verdict
        if diff <= tol:
            verdict = "PASS"
            pass_count += 1
        else:
            verdict = "FAIL"
            fail_count += 1

        dut._log.info(f"[TEST {test_num:2d}/75][GRP {grp}] x_in={x_real:11.5f} (0x{x_q88:04x}) | golden={gld:9.4f} | hw={hw_real:9.4f} | diff={diff:8.4f} | tol={tol:7.4f} | {verdict}")
        test_num += 1

    # -------------------------------------------------------------------------
    # Reset Sequence
    # -------------------------------------------------------------------------
    dut._log.info("Applying Reset...")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 12)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 3)

    # =========================================================================
    # PHASE 1 - INITIAL CONFIGURATION (1 neuron)
    # =========================================================================
    dut._log.info("================================================================")
    dut._log.info("  WNN Q8.8 Single-Neuron Top - Comprehensive Testbench")
    dut._log.info("  75 test vectors | 1 neuron | pipeline ~24 cyc | sim clk 10 ns")
    dut._log.info("================================================================")
    dut._log.info("--- PHASE 1: Configuring 1 neuron ---")

    w_curr, t_curr, d_curr = 1.0, 0.0, 0.80
    await load_neuron(dut, w_curr, t_curr, d_curr)
    dut._log.info("  -> neuron 0 loaded (w=1.0, t=0.0, d=0.80).")

    # GROUP A: Standard functional
    dut._log.info("--- GROUP A: Standard functional values ---")
    grp_a = [0.0, 0.5, -0.5, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0, 5.0, -5.0, 
             10.0, -10.0, 20.0, -20.0, 50.0, -50.0, 75.0, -75.0, 0.25]
    for val in grp_a: await run_test(val, "A")

    # GROUP B: Exact Q8.8 boundary values
    dut._log.info("--- GROUP B: Q8.8 format boundary values ---")
    grp_b = [127.99609375, -128.0, 0.00390625, -0.00390625, 1.0, -1.0, 0.5, -0.5]
    for val in grp_b: await run_test(val, "B")

    # GROUP C: Near-zero / tiny inputs
    dut._log.info("--- GROUP C: Near-zero inputs ---")
    grp_c = [0.001, -0.001, 0.01, -0.01, 0.0078125, -0.0078125]
    for val in grp_c: await run_test(val, "C")

    # GROUP D: Saturation boundary
    dut._log.info("--- GROUP D: Saturation boundary ---")
    grp_d = [100.0, -100.0, 120.0, -120.0, 126.5, -126.5]
    for val in grp_d: await run_test(val, "D")

    # GROUP E: Mathematical constants
    dut._log.info("--- GROUP E: Mathematical constants ---")
    grp_e = [3.14159265, -3.14159265, 2.71828182, -2.71828182, 1.41421356, -1.41421356]
    for val in grp_e: await run_test(val, "E")

    # GROUP F: Random narrow [-5.0, 5.0] (seed=42)
    dut._log.info("--- GROUP F: Random narrow [-5, +5] (seed=42) ---")
    random.seed(42)
    for _ in range(12):
        rnd_val = random.randint(0, 10000) / 1000.0 - 5.0
        await run_test(rnd_val, "F")

    # GROUP G: Random wide [-50.0, 50.0] (seed=137)
    dut._log.info("--- GROUP G: Random wide [-50, +50] (seed=137) ---")
    random.seed(137)
    for _ in range(12):
        rnd_val = random.randint(0, 100000) / 1000.0 - 50.0
        await run_test(rnd_val, "G")

    # =========================================================================
    # PHASE 2 - RECONFIGURATION
    # =========================================================================
    dut._log.info("--- PHASE 2: Reconfiguring neuron 0 to w=1, t=0, d=1 ---")
    w_curr, t_curr, d_curr = 1.0, 0.0, 1.0
    await load_neuron(dut, w_curr, t_curr, d_curr)
    dut._log.info("  -> Reconfiguration complete.")

    # GROUP H: Post-reconfiguration
    dut._log.info("--- GROUP H: Post-reconfiguration (w=1, t=0, d=1) ---")
    grp_h = [0.0, 1.0, -1.0, 2.0, -2.0]
    for val in grp_h: await run_test(val, "H")

    # =========================================================================
    # SUMMARY
    # =========================================================================
    dut._log.info("================================================================")
    dut._log.info(f"  RESULTS  |  PASS: {pass_count:2d}  |  FAIL: {fail_count:2d}  |  TOTAL: {pass_count + fail_count:2d}")
    if fail_count == 0:
        dut._log.info("  STATUS   |  *** ALL TESTS PASSED ***")
    else:
        dut._log.info(f"  STATUS   |  *** {fail_count} FAILURE(S) - inspect diff/tol above ***")
    dut._log.info("================================================================")
    
    assert fail_count == 0, f"Simulation complete with {fail_count} failures."
