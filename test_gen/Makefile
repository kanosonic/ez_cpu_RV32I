.PHONY: all run clean

PROJECT_DIR := $(shell cd .. && pwd)
TOOLCHAIN ?= /home/inori/下载/riscv
QEMU := $(TOOLCHAIN)/bin/qemu-riscv32
AS := $(TOOLCHAIN)/bin/riscv32-unknown-elf-as
OBJCOPY := $(TOOLCHAIN)/bin/riscv32-unknown-elf-objcopy

TEST ?= all
BUILD_DIR := build
TEST_DIR := tests

INSTR_LIST := instr_list.txt

all:
	@echo "Usage: make run [TEST=<instruction>]"
	@echo "  make run             - Run all 37 instructions"
	@echo "  make run TEST=add    - Run single instruction 'add'"

run:
	@if [ "$(TEST)" = "all" ]; then \
		$(SHELL) ./run_all.sh; \
	else \
		$(SHELL) ./run_single.sh $(TEST); \
	fi

clean:
	rm -rf $(BUILD_DIR)
	rm -f ../build/cpu_sim.vvp ../build/cpu_tb.vcd
