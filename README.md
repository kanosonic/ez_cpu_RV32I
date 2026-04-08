# ez_cpu_RV32I

`ez_cpu_RV32I` is a lightweight 5-stage RV32I pipeline CPU for RTL learning, simulation, directed differential testing, and differential fuzzing against a reference simulator.

## Prerequisites

Install these tools first:

- `iverilog`
- `vvp`
- `gtkwave`
- `python3`
- a RISC-V toolchain that provides:
  - `riscv32-unknown-elf-as`
  - `riscv32-unknown-elf-gcc`
  - `riscv32-unknown-elf-objcopy`
  - `riscv32-unknown-elf-objdump`
  - `riscv32-unknown-elf-run`

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
```

## Quick Start

```bash
make asm
make run
make wave
make test
make fuzz
make clean
```

## Make Targets

| Target | Description |
|--------|-------------|
| `make all` | Compile the Verilog testbench binary |
| `make asm` | Build `sim/asm/src/test.asm` into ROM input data |
| `make run` | Run the main testbench on `sim/asm/build/test.dat` |
| `make wave` | Open `build/cpu_tb.vcd` in GTKWave |
| `make test [TEST=name]` | Run directed differential tests, one or all |
| `make fuzz [FUZZ_LOOPS=n] [FUZZ_SEED=s] [FUZZ_STEPS=k]` | Run differential fuzzing |
| `make clean` | Clean top-level, `sim/asm`, and `test_gen` generated files |

## Common Workflows

### Run the default assembly program

```bash
make asm
make run
```

This assembles `sim/asm/src/test.asm`, converts it to the byte-oriented `.dat` format expected by `testbench/cpu_tb.v`, then simulates the CPU.

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

Override the loop count, start seed, or program length:

```bash
make fuzz FUZZ_LOOPS=200
make fuzz FUZZ_SEED=53 FUZZ_LOOPS=1
make fuzz FUZZ_STEPS=64
```

The default fuzz configuration is:

- `FUZZ_LOOPS=1000`
- `FUZZ_SEED=1`
- `FUZZ_STEPS=32`

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
5. Run the RTL CPU on the same program.
6. Compare register state with `test_gen/compare_state.py`.
7. Stop immediately on the first mismatch and print:
   - the failing seed
   - a one-line repro command
   - the artifact directory containing the generated `.asm`, ELF, ROM image, and state dumps

Example repro after a failure:

```bash
make fuzz FUZZ_LOOPS=1 FUZZ_SEED=53 FUZZ_STEPS=32
```

This makes differential fuzz useful for finding pipeline, forwarding, branch, and ALU corner-case bugs with a deterministic seed-based workflow.

## Key Files

- `rtl/core/cpu.v` — top-level 5-stage CPU
- `rtl/component/` — ALU, control, forwarding, hazard, memory, and pipeline modules
- `testbench/cpu_tb.v` — simulation testbench, CPI reporting, and final CPU state dump
- `sim/asm/` — simple hand-written assembly flow for `make run`
- `test_gen/tests/` — directed RV32I differential tests
- `test_gen/run_single.sh` — one directed differential run
- `test_gen/run_all.sh` — batch directed differential tests
- `test_gen/run_fuzz.sh` — differential fuzz loop runner
- `test_gen/generate_fuzz.py` — randomized RV32I program generator
- `test_gen/extract_qemu.py` — reference state extractor
- `test_gen/compare_state.py` — architectural state comparator

## CPI Note

`testbench/cpu_tb.v` reports CPI as:

```text
CPI = executed cycles / executed instructions
```

It counts:

- `cycle_num`: cycles while the pipeline still contains work
- `inst_num`: retired instructions using the write-back stage `PC+4` activity

So the reported CPI is the testbench-level retirement CPI for the simulated program.
