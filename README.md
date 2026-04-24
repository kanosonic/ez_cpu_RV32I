# ez_cpu_RV32I

`ez_cpu_RV32I` is a lightweight 5-stage RV32I pipeline CPU with dynamic branch prediction for RTL learning, simulation, directed differential testing, differential fuzzing, and CoreMark-based branch predictor quantification.

## Prerequisites

Install these tools first:

- `iverilog`
- `vvp`
- `gtkwave`
- `verilator`(optional, for faster CoreMark benchmarking)
- `python3`
- `timeout` (optional, but recommended for benchmark host-side timeout control)
- a RISC-V toolchain that provides:
  - `riscv32-unknown-elf-as`
  - `riscv32-unknown-elf-gcc`
  - `riscv32-unknown-elf-objcopy`
  - `riscv32-unknown-elf-objdump`
  - `riscv32-unknown-elf-run`
- a local CoreMark source tree for the benchmark flow

## Set `TOOLCHAIN`

The project defaults to `/home/inori/下载/riscv`, but you can override it with the `TOOLCHAIN` environment variable.

```bash
export TOOLCHAIN=/path/to/your/riscv-toolchain
```

This directory is expected to contain `bin/`, for example:

```bash
$TOOLCHAIN/bin/riscv32-unknown-elf-gcc
$TOOLCHAIN/bin/riscv32-unknown-elf-run
```

You can also pass it per command:

```bash
make test TOOLCHAIN=/path/to/toolchain
make fuzz TOOLCHAIN=/path/to/toolchain
make benchmark TOOLCHAIN=/path/to/toolchain
```

## Set `COREMARK_DIR`

The benchmark flow expects a CoreMark checkout. The default is `/home/inori/cpu/coremark`, but you can override it with `COREMARK_DIR`.

```bash
export COREMARK_DIR=/path/to/coremark
make benchmark COREMARK_DIR=/path/to/coremark
```

## Quick Start

```bash
make asm
make run
make wave
make test
make fuzz
make benchmark
./quantification/pred/script/run_all.sh --jobs 8
make clean
```

## Make Targets

| Target | Description |
|--------|-------------|
| `make all` | Default top-level target; use `make run` to actually compile and execute the RTL testbench |
| `make asm` | Build `sim/asm/src/test.asm` into ROM input data |
| `make run` | Run the main testbench on `sim/asm/build/test.dat` |
| `make wave` | Open `build/cpu_tb.vcd` in GTKWave |
| `make test [TEST=name]` | Run directed differential tests, one or all |
| `make fuzz [FUZZ_LOOPS=n] [FUZZ_SEED=s] [FUZZ_STEPS=k] [FUZZ_JOBS=n]` | Run differential fuzzing |
| `make benchmark [BENCH_*=...]` | Build and run CoreMark on the RTL CPU with Verilator |
| `make clean` | Clean top-level, `sim/asm`, and `test_gen` generated files |

## Common Workflows

### Run the default assembly program

```bash
make asm
make run
```

This assembles `sim/asm/src/test.asm`, converts it to the byte-oriented `.dat` format expected by `testbench/cpu_tb.v`, then simulates the CPU.

`make run` recompiles the main `iverilog` testbench and runs it on the generated instruction ROM image.

### Run directed differential tests

Run all directed RV32I tests:

```bash
make test
```

Run one instruction only:

```bash
make test TEST=add
make test TEST=jalr
```

### Run differential fuzz

Run with the default 1000 loops:

```bash
make fuzz
```

Override the loop count, start seed, program length, or parallel job count:

```bash
make fuzz FUZZ_LOOPS=200
make fuzz FUZZ_SEED=53 FUZZ_LOOPS=1
make fuzz FUZZ_STEPS=64
make fuzz FUZZ_JOBS=8
```

The default fuzz configuration is:

- `FUZZ_LOOPS=1000`
- `FUZZ_SEED=1`
- `FUZZ_STEPS=32`
- `FUZZ_JOBS=<number of CPU cores>`

`FUZZ_STEPS` is the number of randomized instructions generated in each fuzz program before the final terminal self-loop. Larger values increase coverage but also make each fuzz iteration slower.

## Branch Prediction Unit

The current fetch path includes a simple dynamic branch prediction unit in `rtl/component/bpu.v`.

- `BPU` combines a `BHT` for direction prediction and a `BTB` for target prediction.
- `BHT` uses a 2-bit saturating counter per entry:
  - `00` strongly not taken
  - `01` weakly not taken
  - `10` weakly taken
  - `11` strongly taken
- `BHT` indexing uses a gshare-style global history register:
  - `ghr[7:0]` records recent branch taken/not-taken results
  - `if_index = {if_pc[11:10], ghr ^ if_pc[9:2]}`
  - `ex_index = {ex_pc[11:10], ghr ^ ex_pc[9:2]}`
- `BTB` is a 4-way set-associative target buffer with tree pseudo-LRU replacement.
- Conditional branches are predicted taken only when:
  - the `BTB` hits, and
  - the `BHT` predicts taken
- `jal` is predicted taken on a `BTB` hit.
- `jalr` is still resolved later in the pipeline and is not predicted by the current BPU.
- Predictor state is updated synchronously from EX-stage results, while IF-stage prediction is asynchronous.

On a branch misprediction, the CPU uses `ex_pred_fail = ex_branch_taken ^ ex_pred_branch_taken` to redirect fetch and flush younger wrong-path instructions.

## Differential Test Flow

Directed tests live in `test_gen/tests/`, and `make test` drives them through `test_gen/run_single.sh` or `test_gen/run_all.sh`.

For each test case, the flow is:

1. Assemble the `.asm` file into an object file.
2. Link it at address `0x0` into an ELF reference program.
3. Convert the ELF `.text` section into Verilog hex, then into the byte-wise `.dat` ROM image used by the CPU testbench.
4. Run `riscv32-unknown-elf-run` and trace architectural register writes until the program reaches its terminal loop.
5. Run the Verilog CPU with `iverilog` + `vvp`.
6. Dump the CPU architectural state into `build/cpu_state.txt`.
7. Compare CPU and reference register state with `test_gen/compare_state.py`.

Per-test artifacts are written under `test_gen/build/<test_name>/`.

## Differential Fuzz Flow

`make fuzz` uses `test_gen/run_fuzz.sh` and `test_gen/generate_fuzz.py` to automatically generate randomized RV32I programs and compare the RTL CPU against the reference simulator.

Each fuzz iteration does this:

1. Choose a seed and create a unique run directory such as `test_gen/build/fuzz_00053/`.
2. Generate a randomized RV32I assembly program with:
   - randomized register initialization
   - arithmetic, logic, shift, upper-immediate, load/store, branch, `jal`, and `jalr` instructions
   - a terminal self-loop so both simulators stop at the same architectural point
3. Build the generated assembly into:
   - an ELF for the reference simulator
   - a `.dat` image for the Verilog instruction ROM
4. Extract the final reference architectural state with `test_gen/extract_qemu.py`.
5. Run the RTL CPU on the same program, reusing one compiled simulation binary across fuzz cases.
6. Compare register state with `test_gen/compare_state.py`.
7. Stop immediately on the first mismatch and print:
   - the failing seed
   - a one-line repro command
   - the artifact directory containing the generated `.asm`, ELF, ROM image, and state dumps

For faster fuzzing, `make fuzz FUZZ_JOBS=<n>` runs multiple seeds in parallel and disables VCD dumping during fuzz runs.

Example repro after a failure:

```bash
make fuzz FUZZ_LOOPS=1 FUZZ_SEED=53 FUZZ_STEPS=32
```

This makes differential fuzz useful for finding pipeline, forwarding, branch, and ALU corner-case bugs with a deterministic seed-based workflow.

## CoreMark Benchmark

Run a single CoreMark measurement:

```bash
make benchmark
```

Useful benchmark knobs from `Makefile` are:

- `BENCH_ITERATIONS=10`
- `BENCH_DATA_SIZE=2000`
- `BENCH_OPT=-O2`
- `BENCH_MAX_CYCLES=20000000`
- `BENCH_SIM_TIMEOUT=300`
- `BENCH_VERILATOR_JOBS=<number of CPU cores>`
- `BENCH_DYNAMIC_PREDICTION=1`
- `BENCH_GHR_ON=1`
- `BENCH_BPU_GHR_BITS=8`
- `BENCH_BPU_BHT_INDEX_BITS=10`
- `BENCH_BPU_BHT_HISTORY_BITS=2`

Example:

```bash
make benchmark BENCH_MAX_CYCLES=100000000 BENCH_GHR_ON=0 BENCH_BPU_BHT_INDEX_BITS=9
```

The benchmark flow in `benchmark/run_coremark.sh`:

1. builds a freestanding RV32I CoreMark ELF with the external CoreMark tree
2. converts `.text` into the byte-oriented ROM image used by the RTL testbench
3. converts data sections into a RAM initialization image
4. compiles `testbench/cpu_tb.v` plus the RTL with Verilator
5. runs the simulation with `+NOVCD` and the configured cycle limit
6. prints CPI and branch-prediction statistics parsed later by the quantification scripts

Artifacts are written under `build/benchmark_coremark/` and `build/verilator_bench/`.

## Branch Predictor Quantification

This repo also includes a reproducible CoreMark branch-predictor sweep under `quantification/pred/`.

Run a small smoke test:

```bash
./quantification/pred/script/run_all.sh --cycles 1M --limit-configs 1 --strategy all --jobs 3
```

Run the default sweep:

```bash
./quantification/pred/script/run_all.sh --jobs 8
```

The default sweep uses `BHT_HISTORY_BITS=2` for dynamic prediction:

- `static` uses the default top-level BPU parameters with dynamic prediction disabled
- `ghr_off` keeps `GHR_BITS=0` and sweeps `BHT_INDEX_BITS=1..12`
- `ghr_on` sweeps `GHR_BITS=0..10` and `BHT_INDEX_BITS=1..12` with `BHT_INDEX_BITS > GHR_BITS`

Generated outputs:

- `quantification/pred/record/` — raw measurement records and per-run logs
- `quantification/pred/plot/cycle_branch_accuracy.svg` — best branch accuracy by cycle
- `quantification/pred/plot/cycle_cpi.svg` — best CPI by cycle
- `quantification/pred/plot/ghr_off_idx_accuracy_1000M.svg` — `ghr_off` accuracy versus `BHT_INDEX_BITS`
- `quantification/pred/plot/ghr_on_best_by_ghr_1000M.svg` — best `ghr_on` accuracy versus `GHR_BITS`
- `quantification/pred/plot/ghr_on_accuracy_heatmap.svg` — `ghr_on` accuracy heatmap
- `quantification/pred/report.md` — generated summary report

Note: the first two report figures use the best nonzero-`GHR_BITS` `ghr_on` point at each cycle, restricted to `GHR_BITS=1..10`, so the `ghr_on` curve is directly comparable with `ghr_off` instead of collapsing to the `ghr=0` case.

## Key Files

- `rtl/core/cpu.v` — top-level 5-stage CPU
- `rtl/component/` — ALU, control, forwarding, hazard, memory, and pipeline modules
- `testbench/cpu_tb.v` — simulation testbench, CPI reporting, and final CPU state dump
- `benchmark/run_coremark.sh` — CoreMark build + Verilator benchmark runner
- `sim/asm/` — simple hand-written assembly flow for `make run`
- `test_gen/tests/` — directed RV32I differential tests
- `test_gen/run_single.sh` — one directed differential run
- `test_gen/run_all.sh` — batch directed differential tests
- `test_gen/run_fuzz.sh` — differential fuzz loop runner
- `test_gen/generate_fuzz.py` — randomized RV32I program generator
- `test_gen/extract_qemu.py` — reference state extractor
- `test_gen/compare_state.py` — architectural state comparator
- `quantification/pred/script/run_all.sh` — quantification batch driver
- `quantification/pred/script/run_quantification.py` — parameter sweep runner
- `quantification/pred/script/plot_quantification.py` — SVG/plot generator
- `quantification/pred/script/generate_report.py` — Markdown report generator

## CPI Note

`testbench/cpu_tb.v` reports CPI as:

```text
CPI = executed cycles / executed instructions
```

It counts:

- `cycle_num`: cycles while the pipeline still contains work
- `inst_num`: retired instructions using the write-back stage `PC+4` activity

So the reported CPI is the testbench-level retirement CPI for the simulated program.
