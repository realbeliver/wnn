## How it works

This project implements a single-neuron hardware accelerator for a Weightless Neural Network (WNN). It calculates a localized radial basis function commonly used in specific machine learning models. 

Mathematically, the core computes the following continuous function:
$$y=w \cdot z \cdot \exp(-0.5 \cdot z^2)$$
where $z=\frac{x-t}{d}$

To balance hardware efficiency with dynamic range, the accelerator features a streamlined internal data path:
* **Format:** All inputs, outputs, and internal parameters ($x$, $w$, $t$, $d$, and $y$) use a pure **16-bit Q8.8** signed fixed-point format. This represents a range of **-128** to **+127.99609375** with a resolution of **1/256**.
* **Math Pipeline:** The design features a fully pipelined architecture comprising a 1-cycle saturating multiplier, a 16-cycle restoring divider, and a 64-entry Look-Up Table (LUT) paired with linear interpolation to calculate the exponential function. 
* **Latency:** The core computation pipeline takes exactly **24 cycles**. Accounting for serialization and shifting, the total latency is approximately **29 cycles** from `in_valid` to `out_valid`.

---

## How to test

Because Tiny Tapeout has a limited pin count (8 input pins total), the configuration parameters (48 bits total) and inference data are passed into the neuron serially. 

**1. Configuration Phase:**
You must first configure the neuron's parameters: weight ($w$), threshold ($t$), and divisor ($d$).
* Shift 16 bits of Q8.8 data (LSB first) into **`ui_in[0]`** (`cfg_serial`), setting **`ui_in[1]`** (`cfg_valid`) high for each bit.
* Select the target parameter using **`ui_in[4:3]`** (`cfg_param`): **00** for $w$, **01** for $t$, and **10** for $d$.
* Pulse **`ui_in[2]`** (`cfg_load`) high for one cycle to latch the shifted data into the chosen register.

**2. Inference Phase:**
* Monitor **`uo_out[2]`** (`ready`). When it goes high, the pipeline is idle and ready for the next input.
* Shift a 16-bit Q8.8 input value ($x$) into **`ui_in[5]`** (`x_serial`), setting **`ui_in[6]`** (`x_valid`) high for each bit.

**3. Output Phase:**
* Monitor **`uo_out[1]`** (`sum_valid`). When it goes high, the output shift register is active.
* Read the 16-bit Q8.8 output result serially from **`uo_out[0]`** (`sum_serial`) over the subsequent clock cycles (LSB first).

---

## External hardware

No specialized external hardware is strictly required. However, because the interface relies on precise serial bit-banging and data format conversion (standard floats to the Q8.8 format), connecting the Tiny Tapeout board to a microcontroller (such as a Raspberry Pi Pico or Arduino) or an FPGA is highly recommended to drive the test vectors and capture the results accurately.
