# Project Plan — Time-Multiplexed Fixed-Point FIR Filter

A staged guide for tackling Assignment 6. This is a **roadmap, not a solution** — each
stage tells you *what* to build, *why* it matters, *what to decide*, and *how to know
you got it right*. Work the stages in order; each one depends on the previous.

---

## Stage 0 — Understand the architecture before writing anything

Spend real time here. Everything downstream gets easier if the math is solid first.

### The core idea
A direct-form 64-tap FIR needs 64 multipliers. You only get `M` (e.g. 4). So you
**reuse** those `M` MACs across time: `N / M = 64 / 4 = 16` clock cycles per output sample.

### The key numbers to pin down (with N=64, M=4)
- **Cycles per output sample:** `N/M = 16`
- **Taps handled per MAC:** each of the 4 MACs is responsible for `16` taps over the 16 cycles
- **Per cycle:** read `M=4` coefficients + `M=4` delay-line samples → feed `4` MACs → accumulate
- **After 16 cycles:** you have `M=4` partial sums that must be **summed together** (an adder tree) to form one `y[n]`

> ⚠️ The single most-missed detail: M MACs accumulating in parallel produce **M partial
> sums**, not one. You need a final combine step (adder tree) after the 16 cycles. Decide
> early *which* taps each MAC owns, because that dictates your coefficient and delay-line
> addressing.

### Decision to make now: tap-to-MAC mapping
Two common schemes — pick one and stay consistent everywhere (HW + MATLAB):
- **Interleaved:** cycle `c`, MAC `m` handles tap `k = c*M + m` (taps 0..63 read in order, 4 at a time)
- **Blocked:** MAC `m` handles taps `m*(N/M) .. m*(N/M)+15`

Interleaved is usually the cleaner mapping for coefficient addressing — recommend starting there.

### Do this stage by hand first
On paper, compute `y[n]` for a tiny case (e.g. N=4, M=2, so 2 cycles). Track: which coeff
and which sample each MAC sees each cycle, and how partials combine. If you can't do it on
paper, you can't write the controller.

**Exit check:** you can draw a cycle-by-cycle table (cycle # → coeff addresses → delay-line
indices → MAC accumulations → final combine) for the N=4/M=2 toy case.

---

## Stage 1 — Lock down the fixed-point math

Get the number formats nailed before any RTL, or you'll chase phantom "bugs" later that are
really format mismatches.

### The formats (from the spec)
| Signal | Format | Width | Int+sign | Frac |
|---|---|---:|---:|---:|
| Input `x` | Q2.10 | 12 | 2 | 10 |
| Coeff `h` | Q1.15 | 16 | 1 | 15 |
| Internal | up to Q2.30 | ~32 | | 30 |
| Output `y` | Q2.10 | 12 | 2 | 10 |

### Work out the bit growth yourself
- `x (Q2.10) × h (Q1.15)` → product is **28 bits**, fractional bits `10+15 = 25` → **Q3.25**.
- Accumulating 64 products needs `log2(64) = 6` extra guard bits → ~34-bit accumulator. The
  spec's "Q2.30 / 32-bit internal" is a *target*; reconcile it with your own bit-growth
  calc and document any guard bits you add.
- **Output conversion:** from the accumulator (Q?.25/30) back to Q2.10 you must
  **shift/round, then truncate, then saturate**. Use the *same* strategy as Assignment 4 so
  the comparison is fair.

### Decisions to make and write down
- Rounding: truncate vs round-to-nearest? (Pick what Assignment 4 used.)
- Saturation: clamp to Q2.10 min/max on overflow, or wrap? (Saturation is safer.)
- Signedness: everything is signed two's complement — confirm your tools treat it that way.

**Exit check:** a one-page note (put it in `docs/`) showing, with bit positions, how a
product is formed, how the accumulator grows, and exactly how you get back to Q2.10. This
note becomes the spec your MATLAB *and* Verilog must both match.

---

## Stage 2 — MATLAB golden model FIRST (before RTL)

Build the reference model before the hardware. It defines "correct," and you'll reuse its
fixed-point routines to generate test vectors.

### What to build
1. Load `Neural_Signal_Sample.mat` and `HW6_BPF.mat`. *(Coefficient file is currently
   missing from `data/` — get it from the instructor before this stage.)*
2. Quantize input → Q2.10, coeffs → Q1.15 (use `fi` objects or manual integer scaling).
3. Implement the FIR two ways and confirm they agree:
   - Floating-point reference (`conv`/`filter`) — sanity check.
   - **Fixed-point** model that mimics your hardware *exactly*: same product format, same
     accumulator width, same rounding/saturation, same output truncation.
4. Export the quantized input samples (as integers) to a text file your testbench can
   `$readmemb`/`$readmemh`. Export coefficients the same way.

### Why fixed-point-in-MATLAB matters
If your MATLAB reference is floating-point, you'll see differences vs. Verilog that are just
quantization, and you won't be able to tell real bugs from rounding noise. Match the
hardware bit-for-bit and the expected error becomes ~0.

**Exit check:** MATLAB fixed-point output looks like a sensible band-pass-filtered version
of the neural signal; you have integer text files for input `x` and coeffs `h` ready to feed
the testbench.

---

## Stage 3 — Build the RTL bottom-up, one module at a time

Follow the spec's module breakdown. Build and unit-test the leaf modules before the top.

Suggested build + test order:

### 3a. `fixed_point_mac`
- Multiplier + accumulator, with a clear/load-enable to reset at the start of each output.
- **Unit test it alone:** feed known x,h pairs, check the accumulated value against hand math.

### 3b. `coeff_bram`
- 64 coefficients in Block RAM; must serve `M` coeffs per cycle to the M MACs.
- Decision: M separate BRAMs / banks, or one BRAM with M-wide word, or M reads per cycle.
  M parallel banks (one per MAC) is simplest for the interleaved mapping.
- Initialize from the integer coeff file (`$readmemb`). **Unit test:** read out all 64, compare to file.

### 3c. `fir_delay_line` — the heart of the SRL_REG requirement
- Stores N=64 past samples; must present `M` samples per cycle matching the coeff mapping.
- **`SRL_REG=0`:** plain register array / shift register (inferred FFs).
- **`SRL_REG=1`:** SRL16/SRLC-style addressable shift registers (LUT-based). Note SRL16 has
  *addressable* taps via a 4-bit address but **no async random access** the way a reg file
  has — make sure your access pattern (M taps/cycle) is compatible.
- Use `generate`/`if (SRL_REG)` to select the implementation from one parameter.
- **Unit test:** shift in a known ramp, verify the M tapped outputs each cycle for *both* modes.

### 3d. `fir_time_mux_controller`
- Counts `0 .. (N/M)-1`, generates coeff addresses + delay-line tap selects, enables MACs,
  resets accumulators at cycle 0, and asserts `output_valid` when the sample is ready.
- This is where the cycle-by-cycle table from Stage 0 turns into logic.

### 3e. `fir_time_mux_top`
- Wires delay line + coeff mem + M MACs + controller, plus the **final adder tree** that
  combines the M partial sums, then the output-format conversion (Stage 1).
- Carries the `N`, `M`, `SRL_REG` parameters down to submodules.

### Make it genuinely parametric
- Don't hard-code 64, 4, or 16. Derive `CYCLES = N/M`, address widths from `$clog2`, etc.
- Guard the `N % M == 0` assumption (the spec flags this) — at minimum document it; ideally
  add an `initial`/elaboration assertion.

**Exit check:** each module passes its own small unit test; `top` elaborates with N=64, M=4
for both SRL_REG values without warnings.

---

## Stage 4 — Testbench for the 64-tap design (both SRL modes)

### What it must do
- Instantiate **two** copies of `top`: `SRL_REG=0` and `SRL_REG=1`, same everything else.
- Load input from the neural-signal integer file; load coeffs into both.
- Drive samples at the correct rate: a **new input every `N/M=16` cycles** (one input per
  output computation). Don't push a new sample every cycle.
- Wait for `output_valid`, then capture each instance's output.
- **Account for latency:** the first valid output appears after the pipeline + 16 cycles
  fills. Record the latency so MATLAB can align later.
- Write `fir_output_srl0.txt` and `fir_output_srl1.txt` (one output sample per line, integer
  Q2.10 values).

### Debugging strategy if outputs look wrong
Use systematic isolation, not random tweaks: first confirm SRL0 == SRL1 (they *must* match —
same math, different storage). If they differ, the bug is in the delay line. If they agree
but disagree with MATLAB, it's the math/format or the tap mapping.

**Exit check:** both output files are produced; `srl0` and `srl1` files are **identical**
(this is a strong correctness signal on its own).

---

## Stage 5 — MATLAB verification & plots

### Verification script
- Load the same input + coeffs, run your Stage-2 fixed-point model.
- Read `fir_output_srl0.txt` and `fir_output_srl1.txt`.
- **Align** for latency before comparing (trim the leading samples by the latency from
  Stage 4, or cross-correlate to find the offset).
- Compute `error[n] = abs(y_matlab[n] - y_verilog[n])` for each mode.

### The required figure (1 figure, 2 subplots)
- **Subplot 1 (overlay):** raw input, Verilog SRL0, Verilog SRL1, MATLAB fixed-point output.
- **Subplot 2 (error):** `|MATLAB − Verilog_SRL0|` and `|MATLAB − Verilog_SRL1|`.

**Exit check:** in subplot 1 the three FIR traces sit essentially on top of each other; in
subplot 2 the error is ~0 (a few LSBs at most — only rounding). Large or growing error means
go back to Stage 1/3, not "good enough."

---

## Stage 6 — Synthesis & utilization comparison

### Run it twice
Synthesize `top` with `SRL_REG=0`, then `SRL_REG=1` (same N=64, M=4) in Vivado. Keep both
runs / reports.

### Collect from the utilization report
- Registers / Flip-Flops
- Slice LUTs
- Block RAMs
- DSP48s
- (Anything else notable)

### What you expect to see (and should explain in your writeup)
- `SRL_REG=1` should trade **FFs for LUTs** (SRL16 packs the delay line into LUTs) → fewer
  registers, the delay line moves into SLICEM LUTs.
- BRAM count should be the same (coeffs unchanged); DSPs driven by `M`, not the delay line.
- If the numbers *don't* move that way, your SRL16 probably didn't infer — check the synth
  log for "SRL" / "SRLC" primitives.

**Exit check:** you can articulate *why* each resource changed between the two designs.

---

## Stage 7 — Excel report & final packaging

- Fill `assignment6_utilization.xlsx` with the side-by-side table (SRL0 vs SRL1) for each
  resource type.
- Run the **final checklist** in Section 16 of the requirements — literally tick each box.
- Confirm deliverables present: RTL sources, testbench, MATLAB script, both output `.txt`
  files, the figure, the Excel file.

---

## Suggested repository layout
```
src/Vivado/      fixed_point_mac.v, coeff_bram.v, fir_delay_line.v,
                 fir_time_mux_controller.v, fir_time_mux_top.v, tb_fir.v
src/matlab/      gen_vectors.m, fir_golden_model.m, verify_and_plot.m
data/            Neural_Signal_Sample.mat, HW6_BPF.mat (MISSING — obtain),
                 x_q210.txt, h_q115.txt
out/             fir_output_srl0.txt, fir_output_srl1.txt
docs/            fixed_point_notes.md, cycle_timing_table.md
assignment6_utilization.xlsx
```

## Critical-path / risk summary
1. **Get `HW6_BPF.mat`** — blocks Stages 2, 4, 5. Highest priority.
2. **Fixed-point format discipline** (Stage 1) — the #1 source of "mismatch" bugs.
3. **Tap-to-MAC mapping consistency** — must be identical in controller, coeff mem, delay
   line, and MATLAB. Decide once (Stage 0).
4. **The M-partial-sum adder tree + output conversion** — easy to forget.
5. **Latency alignment** in MATLAB — outputs are correct but shifted in time; align before
   judging error.
6. **SRL16 inference** — verify in the synth log, don't assume.

## Recommended order of attack
Stage 0 → 1 (paper + notes) → 2 (MATLAB golden) → 3 (RTL bottom-up) → 4 (TB) → 5 (verify)
→ 6 (synth) → 7 (package). Do **not** start RTL before the MATLAB golden model exists —
without it you have nothing to check the hardware against.
```
