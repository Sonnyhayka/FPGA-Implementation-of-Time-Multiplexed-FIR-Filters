# Time-Multiplexed Fixed-Point FIR RTL

## Modules

- `fixed_point_mac.sv` implements one signed multiplier and accumulator.
- `fixed_point_output.sv` rounds, shifts, and saturates the accumulated result.
- `coeff_bram.sv` implements the synchronous packed coefficient ROM.
- `fir_delay_line.sv` implements regular registers or inferred SRL16 storage.
- `fir_time_mux_controller.sv` controls the 16-cycle computation and handshake.
- `fir_time_mux_top.sv` connects the controller, memory, delay line, MAC units, adder tree, and output conversion.
- `tb_fir.sv` checks both delay-line variants against all 4000 expected samples.
- `synthesize_variants.tcl` synthesizes both variants and writes reports and checkpoints.

## Fixed-point behavior

Inputs use signed Q2.10. Coefficients use signed Q1.15. Products and the 34-bit accumulator have 25 fractional bits. Output conversion shifts by 15 bits, rounds half away from zero, and saturates to the signed 12-bit Q2.10 range.

MAC lane `m` handles taps `m*(N/M)` through `(m+1)*(N/M)-1`. The `M` partial sums are combined in fabric. One new sample is accepted every `N/M` clocks when `in_valid` remains asserted.

## Icarus Verilog

Run from the `data` directory:

```powershell
iverilog -g2012 -Wall -s tb_fir -o fir_sim ../src/Vivado/fixed_point_mac.sv ../src/Vivado/fixed_point_output.sv ../src/Vivado/coeff_bram.sv ../src/Vivado/fir_delay_line.sv ../src/Vivado/fir_time_mux_controller.sv ../src/Vivado/fir_time_mux_top.sv ../src/Vivado/tb_fir.sv
vvp ./fir_sim
```

The expected terminal result is `tb_fir PASS srl0=4000 srl1=4000`. The run writes `fir_output_srl0.txt` and `fir_output_srl1.txt` in the `data` directory.

## Vivado

Run from the repository root:

```powershell
vivado -mode batch -nojournal -nolog -source ./src/Vivado/synthesize_variants.tcl
```

The script uses `xc7a35tcpg236-1` with a 50 MHz clock constraint, synthesizes `SRL_REG=0` and `SRL_REG=1`, and writes utilization reports, timing reports, XML reports, and checkpoints to `result`.
