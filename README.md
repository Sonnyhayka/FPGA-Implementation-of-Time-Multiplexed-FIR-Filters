# FPGA Time-Multiplexed FIR Filter

This project implements a parametric signed fixed-point FIR filter with `N` taps, `M` time-multiplexed MAC units, a Block RAM coefficient ROM, and selectable register or SRL16 delay storage.

The completed 64-tap, 4-MAC configuration accepts one sample and produces one result every 16 clocks. Both delay-line variants are bit-exact against the 4000-sample fixed-point reference.

## Project contents

- `src/Vivado` contains synthesizable SystemVerilog, the self-checking testbench, and the Vivado synthesis script.
- `src/matlab/fir_golden_model.m` quantizes the source data and generates the fixed-point vectors.
- `src/matlab/verify_and_plot.m` recomputes the expected result, checks both hardware outputs, and generates the required plots.
- `data` contains the source MAT files, quantized vectors, packed coefficient ROM image, and simulation outputs.
- `result` contains Vivado reports, design checkpoints, timing reports, verification plots, and the verification summary.
- `assignment6_utilization.xlsx` contains the side-by-side synthesis utilization report.

## Verification result

- Samples checked: 4000
- `SRL_REG=0` maximum absolute error: 0 LSB
- `SRL_REG=1` maximum absolute error: 0 LSB
- Register and SRL outputs: identical

## Synthesis result

Target device: `xc7a35tcpg236-1` with a 50 MHz clock constraint. Both variants meet timing.

| Resource | `SRL_REG=0` | `SRL_REG=1` |
| --- | ---: | ---: |
| Slice LUTs | 389 | 278 |
| LUTs as shift registers | 0 | 84 |
| Slice registers | 790 | 19 |
| Block RAM tiles | 1 | 1 |
| RAMB18E1 | 2 | 2 |
| DSP48E1 | 4 | 4 |

The SRL implementation removes 771 flip-flops and uses inferred `SRL16E` resources while preserving the same BRAM and DSP counts.

## Tool flows

Detailed Icarus and Vivado commands are in [src/Vivado/README.md](src/Vivado/README.md). Run `fir_golden_model.m` before simulation when regenerating vectors, then run `verify_and_plot.m` after simulation.
