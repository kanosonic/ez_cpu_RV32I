# ez_cpu_RV32I

A lightweight 5-stage pipeline CPU implementation based on RISC-V RV32I instruction set. Designed for educational purposes with complete RTL simulation, assembly support, and waveform analysis.

## Quick Start

```bash
# Build and run simulation with assembly test
make asm       # Compile assembly code to instruction hex
make run       # Execute simulation and generate waveform
make wave      # View waveform in GTKWave
make clean     # Remove all build artifacts
```

## Project Structure

### RTL Design (`rtl/`)

**Core Module:**

- [`cpu.v`](rtl/core/cpu.v) — Main CPU with 5-stage pipeline (IF→ID→EX→MEM→WB)

**Pipeline Stages & Components (`rtl/component/`):**

- `pc.v` / `next_pc.v` — Program counter and next address calculation
- `if_id.v`, `id_ex.v`, `ex_mem.v`, `mem_wb.v` — Pipeline registers
- `imm_gen.v` — Immediate value generator
- `reg_file.v` — 32 general-purpose registers
- `alu.v` / `alu_ctrl.v` — Arithmetic Logic Unit with control logic
- `adder32.v` — 32-bit adder for address/arithmetic
- `controller.v` — Instruction decode and control signal generation

**Memory & Forwarding:**

- `inst_rom.v` — Instruction memory (ROM)
- `data_ram.v` — Data memory (RAM)
- `forward_unit.v` — Forwarding logic for data hazards
- `hazard_detector.v` — Pipeline hazard detection

**Definitions:**

- `define.v` — Macro definitions and constants

### Simulation & Testing (`sim/`)

**Assembly Tests (`sim/asm/`):**

- [`src/test.asm`](sim/asm/src/test.asm) — RISC-V RV32I assembly test program
- `build/test.dump` — Disassembly output
- `build/test.hex` — Verilog hex format (loaded into instruction ROM)

**Makefile:** Compiles assembly using `riscv32-unknown-elf-as` toolchain

### Testbench (`testbench/`)

- [`cpu_tb.v`](testbench/cpu_tb.v) — Top-level simulation testbench
  - Initializes clock (100MHz), reset, and instruction memory
  - Runs for 15µs (configurable)
  - Outputs: PC, instruction count, cycle count, CPI
  - Generates `build/cpu_tb.vcd` waveform file

## Make Targets

| Target | Description |
|--------|-------------|
| `make all` | Compile Verilog sources (default) |
| `make asm` | Compile assembly files and convert to hex format |
| `make run` | Execute simulation: compile + simulate + generate waveform |
| `make wave` | Open waveform in GTKWave (requires existing VCD file) |
| `make clean` | Remove build artifacts (build/ and assembly outputs) |

## Prerequisites

**Required Tools:**

- `iverilog` — Verilog simulation compiler
- `vvp` — Verilog simulation runtime
- `gtkwave` — Waveform viewer
- `riscv32-unknown-elf-as` — RISC-V assembler
- `riscv32-unknown-elf-objdump` — Disassembler
- `riscv32-unknown-elf-objcopy` — Binary converter
- `python3` — For hex conversion script


## Typical Workflow

1. **Write or modify assembly test:**

   ```bash
   vim sim/asm/src/test.asm
   ```

2. **Compile assembly to instructions:**

   ```bash
   make asm
   ```

3. **Run simulation:**

   ```bash
   make run
   ```

4. **Analyze results:**
   - Check simulation output for cycles/CPI
   - View waveform: `make wave`
   - Examine register/memory state in GTKWave

## Pipeline Architecture

The 5-stage pipeline processes instructions through:

- **IF (Instruction Fetch)** — Fetch from `inst_rom` using PC
- **ID (Instruction Decode)** — Decode instruction, read registers, generate immediates
- **EX (Execute)** — ALU operations, address calculation, branch evaluation
- **MEM (Memory)** — Data memory read/write operations
- **WB (Write-Back)** — Write results to register file

**Features:**

- Forwarding unit handles data dependencies
- Hazard detector manages stalls and flushes
- Branch prediction with pipeline flush on misprediction

## File Paths

- Build outputs: `build/` (VCD waveforms, compiled binaries)
- RTL source: `rtl/` (verilog designs)
- Simulation: `testbench/` (test benches)
- Test programs: `sim/asm/` (assembly source) and `sim/c_file/` (C programs)
