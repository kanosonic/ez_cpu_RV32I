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

# Rule to compile Verilog sources into simulation binary
#$(BIN): $(SRC) $(TEST_SRC) | $(BUILD_DIR)
##	iverilog -I rtl -I rtl/component -o $(BIN) -s $(TOP) $(SRC) $(TEST_SRC)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: all clean sim run asm

# Default target: compile all Verilog sources
all: $(BIN)

# Run simulation and generate waveform
wave: $(BIN)
	gtkwave $(VCD) 

# Run simulation without generating waveform
run: $(BIN)
	@echo "Running simulation..."
	sed -i 's#.hex#${TEST_HEX}#' $(TEST_SRC)
	iverilog -I rtl -I rtl/component -o $(BIN) -s $(TOP) $(SRC) $(TEST_SRC)
	vvp $(BIN)
	

# Compile assembly files and convert to byte format
asm:
	@echo Compiling assembly files in $(ASM_DIR)
	make -C $(ASM_DIR)
	@echo Converting assembly output to byte format
	python3 $(ASM_DIR)/word2byte.py


clean:
	@echo Cleaning Verilog build directory...
	rm -rf $(BUILD_DIR)
	@echo Cleaning assembly compilation artifacts...
	make -C $(ASM_DIR) clean
	@echo All clean completed