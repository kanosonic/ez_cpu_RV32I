TOP = cpu_tb
# Collect all Verilog source files
SRC = $(wildcard rtl/*.v) $(wildcard rtl/component/*.v) $(wildcard rtl/core/*.v)

# Testbench source file path
TEST_SRC= testbench/$(TOP).v

# Build directory for compilation outputs
BUILD_DIR = build

# Compiled simulation binary
BIN = $(BUILD_DIR)/$(TOP).vvp

# Waveform output file
VCD = $(BUILD_DIR)/$(TOP).vcd

# Assembly source directory
ASM_DIR = sim/asm

# Compiled test instruction file (output from asm compilation)
TEST_HEX := $(ASM_DIR)/build/test.dat

# Test configuration
TEST ?= all
FUZZ_LOOPS ?= 1000
FUZZ_SEED ?= 1
FUZZ_STEPS ?= 32
FUZZ_JOBS ?= $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
TOOLCHAIN ?= /home/inori/下载/riscv
export TOOLCHAIN

# Rule to compile Verilog sources into simulation binary
$(BIN): $(SRC) $(TEST_SRC) | $(BUILD_DIR)
##	iverilog -I rtl -I rtl/component -o $(BIN) -s $(TOP) $(SRC) $(TEST_SRC)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: all clean sim run asm test fuzz

# Default target: compile all Verilog sources
all: $(BIN)

# Run simulation and generate waveform
wave: $(BIN)
	gtkwave $(VCD) 

# Run simulation without generating waveform
run: $(BIN)
	@echo "Running simulation..."
	iverilog -I rtl -I rtl/component -o $(BIN) -s $(TOP) $(SRC) $(TEST_SRC)
	vvp $(BIN) +HEXFILE=$(TEST_HEX)
	
# Compile assembly files and convert to byte format
asm:
	@echo Compiling assembly files in $(ASM_DIR)
	make -C $(ASM_DIR)
	@echo Converting assembly output to byte format
	python3 $(ASM_DIR)/word2byte.py

# Run differential tests (RV32I)
# Usage: make test TEST=<instruction>  (e.g., make test TEST=add)
#        make test                     (run all 37 instructions)
test:
	@if [ "$(TEST)" = "all" ]; then \
		echo "Running all RV32I differential tests..."; \
		cd test_gen && ./run_all.sh; \
	else \
		echo "Running differential test for: $(TEST)"; \
		cd test_gen && ./run_single.sh $(TEST); \
	fi

# Run randomized differential tests
# Usage: make fuzz
#        make fuzz FUZZ_LOOPS=200 FUZZ_SEED=123 FUZZ_STEPS=48 FUZZ_JOBS=8
fuzz:
	@echo "Running RV32I differential fuzz tests..."
	@cd test_gen && \
		FUZZ_LOOPS=$(FUZZ_LOOPS) FUZZ_SEED=$(FUZZ_SEED) FUZZ_STEPS=$(FUZZ_STEPS) FUZZ_JOBS=$(FUZZ_JOBS) ./run_fuzz.sh

clean:
	@echo Cleaning Verilog build directory...
	rm -rf $(BUILD_DIR)
	@echo Cleaning assembly compilation artifacts...
	make -C $(ASM_DIR) clean
	@echo Cleaning differential test artifacts...
	make -C test_gen clean
	@echo All clean completed
