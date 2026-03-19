TOP = cpu_tb
SRC = $(wildcard src/*.v) $(wildcard src/component/*.v) $(wildcard src/core/*.v)
TEST_SRC= testbench/$(TOP).v
BUILD_DIR = build
BIN = $(BUILD_DIR)/$(TOP).vvp
VCD = $(BUILD_DIR)/$(TOP).vcd

$(BIN): $(SRC) $(TEST_SRC) | $(BUILD_DIR)
	iverilog -I src -I src/component -o $(BIN) -s $(TOP) $(SRC) $(TEST_SRC)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: all clean sim

all: $(BIN)

sim: $(BIN)
	vvp $(BIN)
	@echo Open waveform
	gtkwave $(VCD)

clean:
	rm -rf $(BUILD_DIR)
