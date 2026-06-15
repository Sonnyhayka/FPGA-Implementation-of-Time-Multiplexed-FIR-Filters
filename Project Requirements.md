# Assignment 6: Unified Project Requirements  
## FPGA Implementation of Time-Multiplexed Fixed-Point FIR Filters

## 1. Project Goal

Design, verify, synthesize, and analyze a **parametric time-multiplexed fixed-point FIR filter** for FPGA implementation.

The main purpose of this assignment is to improve upon the direct-form FIR filter from Assignment 4 by reducing hardware resource usage. Instead of using one multiplier for every filter tap, this design must reuse a smaller number of fixed-point multiply-and-accumulate units.

The final design must support:

- A configurable FIR filter order or number of taps
- A configurable number of MAC units
- Fixed-point input, coefficient, internal, and output formats
- Coefficients stored in Block RAM
- Two delay-line implementations selected through the `SRL_REG` parameter
- Verification against MATLAB fixed-point FIR results
- FPGA synthesis comparison between regular registers and SRL16-based delay registers

---

## 2. Background

A high-order FIR filter can approximate an ideal “brick wall” response more closely than a low-order filter. A direct-form FIR implementation normally requires `N` multipliers and `N - 1` adders for an `N`-tap filter. This approach is simple but can consume a large amount of FPGA resources.

To reduce hardware usage, Assignment 6 requires a **time-multiplexed FIR architecture**. In this architecture, only `M` MAC units are implemented in hardware, and those MAC units are reused across multiple clock cycles to compute one FIR output sample.

For an `N`-tap FIR filter using `M` MAC units:

```text
Cycles per output sample = N / M
```

A new output sample is created every `N / M` clock cycles.

The effective input sample rate is therefore:

```text
Input sample rate = fc / (N / M)
```

where `fc` is the FPGA clock frequency.

---

## 3. FIR Filter Equation

The FIR filter should implement the standard convolution equation:

```text
y[n] = h[0]x[n] + h[1]x[n-1] + h[2]x[n-2] + ... + h[N-1]x[n-(N-1)]
```

where:

- `x[n]` is the current input sample
- `h[k]` is the kth FIR coefficient
- `y[n]` is the filtered output sample
- `N` is the number of filter taps

---

## 4. Main Hardware Design Requirements

### 4.1 Time-Multiplexed FIR Filter

Design an `N`-tap FIR filter using `M` time-multiplexed MAC units.

Each MAC unit must include:

- One fixed-point multiplier
- One fixed-point accumulator

The MAC units should be reused over multiple cycles until all `N` tap products have been computed and accumulated.

The design must produce one valid output every `N / M` cycles.

---

### 4.2 Parametric Design

The design must be fully parametric. At minimum, the hardware should support parameters such as:

```verilog
parameter N        = 64;  // Number of filter taps
parameter M        = 4;   // Number of MAC units
parameter SRL_REG  = 0;   // Delay-line implementation selector
```

Additional useful parameters may include:

```verilog
parameter IN_WIDTH     = 12;
parameter COEFF_WIDTH  = 16;
parameter INTERNAL_WIDTH = 32;
parameter OUT_WIDTH    = 12;
```

The exact bit widths should follow the same fixed-point formats used in Assignment 4 unless otherwise specified by the instructor.

---

## 5. Fixed-Point Format Requirements

Use the same fixed-point format rules from Assignment 4.

### 5.1 Input Signal Format

The input signal should use:

```text
Q2.10 format
```

This means:

- Total width: 12 bits
- 2 integer/sign bits
- 10 fractional bits

---

### 5.2 Filter Coefficient Format

The FIR coefficients should use:

```text
Q1.15 format
```

This means:

- Total width: 16 bits
- 1 integer/sign bit
- 15 fractional bits

---

### 5.3 Internal Computation Format

The internal multiplier and accumulator values may grow up to:

```text
Q2.30 format
```

This gives enough precision for multiplication and accumulation.

---

### 5.4 Output Format

The final FIR output should be converted back to:

```text
Q2.10 format
```

The output should be properly shifted, truncated, rounded, or saturated according to the design approach used in Assignment 4.

---

## 6. Coefficient Memory Requirements

The FIR filter coefficients must be stored in a separate memory module.

Requirements:

- Store the coefficients in Block RAM
- Load the coefficients from `HW6_BPF.mat`
- Use `$readmemb` or an equivalent method in the testbench if converting the coefficient file to a text or binary memory format
- The coefficient memory should be separate from the main FIR computation module
- The coefficient memory should provide coefficients to the MAC units during the time-multiplexed computation

---

## 7. Delay Line Requirements

The design must include a delay line for storing past input samples.

The delay line must support two implementation modes using the `SRL_REG` parameter.

### 7.1 Regular Register Delay Line

When:

```verilog
SRL_REG = 0
```

the delay line must be implemented using regular FPGA registers.

---

### 7.2 SRL16 Delay Line

When:

```verilog
SRL_REG = 1
```

the delay line must be implemented using SRL16-based shift registers.

This allows comparison between a normal register-based delay line and an FPGA shift-register-LUT implementation.

---

## 8. Required Filter Configuration for Final Testing

For final testing and synthesis comparison, use:

```text
Filter order / number of taps: 64
```

Both versions must be tested:

```text
Version 1: SRL_REG = 0
Version 2: SRL_REG = 1
```

Each version should use the same:

- Input signal
- FIR coefficients
- Fixed-point formats
- Number of taps
- Number of MAC units
- Testbench structure

---

## 9. Testbench Requirements

Create a testbench for the 64-tap time-multiplexed FIR filter.

The testbench must instantiate and verify both delay-line versions:

```text
Instance 1: SRL_REG = 0
Instance 2: SRL_REG = 1
```

The testbench should:

- Load the input signal from `Neural_Signal_Sample.mat`
- Load the FIR coefficients from `HW6_BPF.mat`
- Feed the input samples into the FIR design at the correct time-multiplexed sample rate
- Wait for valid output samples
- Save the output from each FIR instance into a separate text file
- Make sure the output timing accounts for the `N / M` cycle latency between valid output samples

Suggested output files:

```text
fir_output_srl0.txt
fir_output_srl1.txt
```

---

## 10. MATLAB Verification Requirements

Use MATLAB to verify the Verilog FIR output against MATLAB’s fixed-point FIR implementation.

The MATLAB script should:

- Load `Neural_Signal_Sample.mat`
- Load `HW6_BPF.mat`
- Convert the input signal and coefficients into the correct fixed-point formats
- Compute the expected FIR output using MATLAB fixed-point arithmetic
- Read the Verilog output files from both hardware implementations
- Compare MATLAB output against:
  - Verilog output with `SRL_REG = 0`
  - Verilog output with `SRL_REG = 1`

---

## 11. MATLAB Plot Requirements

Create one MATLAB figure with two subplots.

### Subplot 1

Overlay the following signals:

- Raw input signal
- Verilog FIR output with `SRL_REG = 0`
- Verilog FIR output with `SRL_REG = 1`
- MATLAB fixed-point FIR output

This subplot should show whether the Verilog FIR output matches MATLAB’s expected FIR behavior.

---

### Subplot 2

Plot the absolute error/difference between MATLAB and Verilog outputs.

At minimum, include:

- Absolute difference between MATLAB output and Verilog output with `SRL_REG = 0`
- Absolute difference between MATLAB output and Verilog output with `SRL_REG = 1`

A useful error equation is:

```text
error[n] = abs(y_matlab[n] - y_verilog[n])
```

---

## 12. Synthesis Requirements

Synthesize both versions of the 64-tap FIR filter:

```text
Design 1: SRL_REG = 0
Design 2: SRL_REG = 1
```

The goal is to compare the FPGA resource utilization of the two delay-line implementations.

The synthesis results should include at least:

- Number of registers / flip-flops
- Number of Slice LUTs
- Number of Block RAMs
- Number of DSP48s
- Any other useful FPGA utilization information

---

## 13. Excel Utilization Report

Save the synthesis utilization information into an Excel file.

Suggested file name:

```text
assignment6_utilization.xlsx
```

The Excel file should compare the two designs side by side.

Suggested table format:

| Resource Type | SRL_REG = 0 | SRL_REG = 1 |
|---|---:|---:|
| Registers / Flip-Flops |  |  |
| Slice LUTs |  |  |
| Block RAMs |  |  |
| DSP48s |  |  |
| Other Resources |  |  |

---

## 14. Suggested Module Breakdown

A clean implementation may use the following modules.

### 14.1 Top-Level FIR Module

Responsible for connecting all submodules.

Possible module name:

```verilog
fir_time_mux_top
```

Responsibilities:

- Accept input samples
- Control the delay line
- Control coefficient reads
- Control the MAC units
- Produce valid output samples
- Support the `SRL_REG` parameter

---

### 14.2 Delay Line Module

Possible module name:

```verilog
fir_delay_line
```

Responsibilities:

- Store current and previous input samples
- Support regular register mode when `SRL_REG = 0`
- Support SRL16 mode when `SRL_REG = 1`

---

### 14.3 Coefficient Memory Module

Possible module name:

```verilog
coeff_bram
```

Responsibilities:

- Store FIR coefficients
- Provide coefficients to MAC units
- Use Block RAM inference or explicit BRAM instantiation

---

### 14.4 MAC Unit Module

Possible module name:

```verilog
fixed_point_mac
```

Responsibilities:

- Multiply fixed-point input samples by fixed-point coefficients
- Accumulate products
- Clear accumulator at the beginning of each output computation
- Output the accumulated fixed-point result

---

### 14.5 Controller Module

Possible module name:

```verilog
fir_time_mux_controller
```

Responsibilities:

- Count computation cycles from `0` to `(N / M) - 1`
- Generate coefficient addresses
- Select delay-line samples
- Enable MAC operations
- Generate output-valid signal
- Reset accumulators at the correct time

---

## 15. Required Deliverables

Submit the following items.

### 15.1 Verilog/SystemVerilog Source Files

Include all hardware modules required for the time-multiplexed FIR filter.

At minimum:

- Top-level FIR module
- Delay-line module
- Coefficient memory module
- MAC unit module
- Controller logic
- Any fixed-point helper modules

---

### 15.2 Testbench

Submit a 64-tap testbench that verifies both:

- `SRL_REG = 0`
- `SRL_REG = 1`

The testbench should write the output of each design instance into a different output text file.

---

### 15.3 MATLAB Verification Script

Submit a MATLAB script that:

- Loads the input signal
- Loads the coefficients
- Computes the expected fixed-point FIR output
- Reads both Verilog output files
- Generates the required two-subplot figure
- Computes the absolute difference between MATLAB and Verilog results

---

### 15.4 Output Text Files

Submit the Verilog-generated FIR output files, such as:

```text
fir_output_srl0.txt
fir_output_srl1.txt
```

---

### 15.5 MATLAB Plots

Submit the MATLAB figure containing:

1. Raw signal vs Verilog FIR signal vs MATLAB FIR signal
2. Absolute difference between MATLAB and Verilog outputs

---

### 15.6 Excel Utilization File

Submit an Excel file comparing synthesized utilization results for:

- `SRL_REG = 0`
- `SRL_REG = 1`

The Excel file should include:

- Registers / flip-flops
- Slice LUTs
- Block RAMs
- DSP48s
- Any other relevant utilization numbers

---

## 16. Final Checklist

Before submitting, verify the following:

- [ ] FIR filter is time-multiplexed using `M` MAC units
- [ ] Design is parametric for `N`, `M`, and `SRL_REG`
- [ ] Coefficients are stored in a separate Block RAM memory
- [ ] Delay line supports regular registers when `SRL_REG = 0`
- [ ] Delay line supports SRL16s when `SRL_REG = 1`
- [ ] Final configuration uses a 64-tap FIR filter
- [ ] Input signal uses `Neural_Signal_Sample.mat`
- [ ] FIR coefficients use `HW6_BPF.mat`
- [ ] Fixed-point formats follow Assignment 4
- [ ] Testbench runs both `SRL_REG` versions
- [ ] Each Verilog FIR instance writes to a different output text file
- [ ] MATLAB computes the expected fixed-point FIR output
- [ ] MATLAB compares both Verilog outputs against the expected output
- [ ] MATLAB figure includes the required two subplots
- [ ] Both designs are synthesized
- [ ] FPGA utilization results are saved in an Excel file
- [ ] Registers, Slice LUTs, Block RAMs, and DSP48s are reported

---

## 17. Notes and Assumptions

- The phrase “64th-order” appears to be used by the instructor as the required final test size. Treat this as a 64-tap FIR filter unless the instructor explicitly defines order differently.
- `N` should preferably be divisible by `M` so that each output sample completes in exactly `N / M` cycles.
- If `N` is not divisible by `M`, the design should either reject that parameter combination or handle the final partial MAC group carefully.
- The MATLAB and Verilog outputs may need alignment because FIR filters and time-multiplexed architectures introduce latency.
- Use the same fixed-point conversion strategy as Assignment 4 to make comparison fair.
- The main grading focus is likely correctness, parameterization, SRL/register comparison, MATLAB verification, and synthesis utilization analysis.
