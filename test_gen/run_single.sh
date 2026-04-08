#!/bin/bash
set -euo pipefail

INSTR=$1

if [ -z "$INSTR" ]; then
    echo "Usage: $0 <instruction>"
    exit 1
fi

TOOLCHAIN="${TOOLCHAIN:-/home/inori/下载/riscv}"
QEMU=${TOOLCHAIN}/bin/qemu-riscv32
AS=${TOOLCHAIN}/bin/riscv32-unknown-elf-as
OBJCOPY=${TOOLCHAIN}/bin/riscv32-unknown-elf-objcopy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="${SCRIPT_DIR}/tests"
RUN_NAME="${RUN_NAME_OVERRIDE:-${INSTR}}"
BUILD_DIR="${PROJECT_DIR}/test_gen/build/${RUN_NAME}"
REL_BUILD_DIR="test_gen/build/${RUN_NAME}"
SIM_LOG="${BUILD_DIR}/cpu_sim.log"
METRICS_FILE="${BUILD_DIR}/cpu_metrics.txt"

echo "=== Testing instruction: ${INSTR} ==="

mkdir -p "${BUILD_DIR}"

ASM_FILE="${ASM_FILE_OVERRIDE:-${TEST_DIR}/${INSTR}.asm}"
if [ ! -f "${ASM_FILE}" ]; then
    echo "Error: Test file ${ASM_FILE} not found!"
    exit 1
fi

echo "Step 1: Building reference ELF..."
# Compile to object file
${AS} -march=rv32i -mabi=ilp32 -c -o "${BUILD_DIR}/${RUN_NAME}.o" "${ASM_FILE}" 2>&1 || {
    echo "Error: Assembly failed for ${INSTR}"
    exit 1
}

${TOOLCHAIN}/bin/riscv32-unknown-elf-gcc -nostdlib -nostartfiles -Ttext=0x0 -o "${BUILD_DIR}/${RUN_NAME}.elf" "${BUILD_DIR}/${RUN_NAME}.o" 2>&1 || {
    echo "Error: Linking failed for ${INSTR}"
    exit 1
}

echo "Step 2: Compiling for CPU (hex format)..."
${OBJCOPY} -O verilog --only-section=.text "${BUILD_DIR}/${RUN_NAME}.elf" "${BUILD_DIR}/${RUN_NAME}.hex"

python3 "${SCRIPT_DIR}/word2byte.py" "${BUILD_DIR}/${RUN_NAME}.hex" "${BUILD_DIR}/${RUN_NAME}.dat"

echo "Step 3: Extracting reference state..."
python3 "${SCRIPT_DIR}/extract_qemu.py" "${BUILD_DIR}/${RUN_NAME}.elf" "${BUILD_DIR}/qemu_state.txt"

echo "Step 4: Running CPU simulation..."
cd "${PROJECT_DIR}"
mkdir -p build
rm -f build/cpu_state.txt
rm -f "${SIM_LOG}" "${METRICS_FILE}"

iverilog -g2012 -I rtl -I rtl/component -o build/cpu_sim.vvp \
    testbench/cpu_tb.v rtl/core/cpu.v rtl/component/*.v 2>&1 || {
    echo "Error: iverilog failed"
    exit 1
}

vvp build/cpu_sim.vvp +HEXFILE="${REL_BUILD_DIR}/${RUN_NAME}.dat" > "${SIM_LOG}" 2>&1

if [ ! -f "${PROJECT_DIR}/build/cpu_state.txt" ]; then
    echo "Error: CPU simulation did not produce build/cpu_state.txt"
    exit 1
fi

CPI_VALUE="$(awk '/^CPI = / {print $3}' "${SIM_LOG}" | tail -n 1)"
if [ -z "${CPI_VALUE}" ]; then
    echo "Error: Failed to extract CPI from ${SIM_LOG}"
    exit 1
fi

printf 'CPI=%s\n' "${CPI_VALUE}" > "${METRICS_FILE}"

echo "Step 5: Copying CPU state..."
cp "${PROJECT_DIR}/build/cpu_state.txt" "${BUILD_DIR}/cpu_state.txt"

echo "Step 6: Comparing states..."
if python3 "${SCRIPT_DIR}/compare_state.py" "${BUILD_DIR}/cpu_state.txt" "${BUILD_DIR}/qemu_state.txt"; then
    echo "CPI: ${CPI_VALUE}"
    echo "Result: PASS"
    exit 0
else
    echo "CPI: ${CPI_VALUE}"
    echo "Result: FAIL"
    echo "--- CPU State ---"
    head -40 "${BUILD_DIR}/cpu_state.txt" 2>/dev/null || true
    echo "--- QEMU State ---"
    head -40 "${BUILD_DIR}/qemu_state.txt" 2>/dev/null || true
    exit 1
fi
