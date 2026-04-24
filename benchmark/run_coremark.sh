#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COREMARK_DIR="${COREMARK_DIR:-/home/inori/cpu/coremark}"
TOOLCHAIN="${TOOLCHAIN:-/home/inori/下载/riscv}"
ITERATIONS="${BENCH_ITERATIONS:-10}"
TOTAL_DATA_SIZE="${BENCH_DATA_SIZE:-2000}"
OPT_LEVEL="${BENCH_OPT:--O2}"
MAX_CYCLES="${BENCH_MAX_CYCLES:-20000000}"
SIM_TIMEOUT="${BENCH_SIM_TIMEOUT:-300}"
VERILATOR_JOBS="${BENCH_VERILATOR_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
DYNAMIC_PREDICTION="${BENCH_DYNAMIC_PREDICTION:-1}"
GHR_ON="${BENCH_GHR_ON:-1}"
BPU_GHR_BITS="${BENCH_BPU_GHR_BITS:-8}"
BPU_BHT_INDEX_BITS="${BENCH_BPU_BHT_INDEX_BITS:-10}"
BPU_BHT_HISTORY_BITS="${BENCH_BPU_BHT_HISTORY_BITS:-2}"
RUN_ID="${BENCH_RUN_ID:-}"

CC="${TOOLCHAIN}/bin/riscv32-unknown-elf-gcc"
OBJCOPY="${TOOLCHAIN}/bin/riscv32-unknown-elf-objcopy"
VERILATOR="${VERILATOR:-verilator}"

RUN_NAME="coremark"
if [ -n "${RUN_ID}" ]; then
    BUILD_DIR="${PROJECT_DIR}/build/benchmark_coremark/${RUN_ID}"
    SIM_MDIR="${PROJECT_DIR}/build/verilator_bench/${RUN_ID}"
else
    BUILD_DIR="${PROJECT_DIR}/build/benchmark_coremark"
    SIM_MDIR="${PROJECT_DIR}/build/verilator_bench"
fi
ELF="${BUILD_DIR}/${RUN_NAME}.elf"
TEXT_HEX="${BUILD_DIR}/${RUN_NAME}.hex"
TEXT_DAT="${BUILD_DIR}/${RUN_NAME}.dat"
DATA_HEX="${BUILD_DIR}/${RUN_NAME}_data.hex"
SIM_BIN="${SIM_MDIR}/Vcpu_tb"
SIM_LOG="${BUILD_DIR}/cpu_sim.log"
STATE_FILE="${BUILD_DIR}/cpu_state.txt"

mkdir -p "${BUILD_DIR}" "${PROJECT_DIR}/build"

echo "Building CoreMark benchmark ELF..."
"${CC}" \
    -march=rv32i -mabi=ilp32 \
    ${OPT_LEVEL} \
    -ffreestanding -fno-builtin -fno-common \
    -fdata-sections -ffunction-sections \
    -fno-asynchronous-unwind-tables -fno-unwind-tables \
    -fno-pic -fno-pie \
    -I"${COREMARK_DIR}" -I"${SCRIPT_DIR}" \
    -DITERATIONS="${ITERATIONS}" \
    -DTOTAL_DATA_SIZE="${TOTAL_DATA_SIZE}" \
    -DPERFORMANCE_RUN=1 \
    -DFLAGS_STR=\"${OPT_LEVEL}\" \
    -Wl,-T,"${SCRIPT_DIR}/coremark_link.ld" \
    -Wl,--gc-sections \
    -nostartfiles -nostdlib \
    -o "${ELF}" \
    "${SCRIPT_DIR}/coremark_start.S" \
    "${SCRIPT_DIR}/coremark_port.c" \
    "${SCRIPT_DIR}/runtime.c" \
    "${COREMARK_DIR}/core_list_join.c" \
    "${COREMARK_DIR}/core_main.c" \
    "${COREMARK_DIR}/core_matrix.c" \
    "${COREMARK_DIR}/core_state.c" \
    "${COREMARK_DIR}/core_util.c" \
    -lgcc

echo "Preparing ROM and RAM images..."
"${OBJCOPY}" -O verilog --only-section=.text "${ELF}" "${TEXT_HEX}"
python3 "${PROJECT_DIR}/test_gen/word2byte.py" "${TEXT_HEX}" "${TEXT_DAT}"

"${OBJCOPY}" -O verilog \
    --remove-section=.text \
    --remove-section=.bss \
    --remove-section=.sbss \
    "${ELF}" "${DATA_HEX}"

echo "Compiling shared simulation binary with Verilator..."
"${VERILATOR}" \
    --binary \
    --timing \
    -Wno-fatal \
    -j "${VERILATOR_JOBS}" \
    "-DDYNAMIC_PREDICTION=${DYNAMIC_PREDICTION}" \
    "-DGHR_ON=${GHR_ON}" \
    "-DBPU_GHR_BITS=${BPU_GHR_BITS}" \
    "-DBPU_BHT_INDEX_BITS=${BPU_BHT_INDEX_BITS}" \
    "-DBPU_BHT_HISTORY_BITS=${BPU_BHT_HISTORY_BITS}" \
    -I"${PROJECT_DIR}/rtl" \
    -I"${PROJECT_DIR}/rtl/component" \
    --top-module cpu_tb \
    -Mdir "${SIM_MDIR}" \
    "${PROJECT_DIR}/testbench/cpu_tb.v" \
    "${PROJECT_DIR}/rtl/core/cpu.v" \
    "${PROJECT_DIR}/rtl/component/"*.v

echo "Running CoreMark on RTL..."
SIM_ARGS=(
    "${SIM_BIN}"
    "+HEXFILE=${TEXT_DAT}"
    "+DATAFILE=${DATA_HEX}"
    "+STATEFILE=${STATE_FILE}"
    "+MAXCYCLES=${MAX_CYCLES}"
    "+NOVCD"
)

if command -v timeout >/dev/null 2>&1; then
    set +e
    timeout --kill-after=5s "${SIM_TIMEOUT}s" "${SIM_ARGS[@]}" > "${SIM_LOG}" 2>&1
    SIM_STATUS=$?
    set -e
    if [ "${SIM_STATUS}" -eq 124 ]; then
        echo "Error: Benchmark simulation timed out after ${SIM_TIMEOUT}s (host wall clock)"
        echo "Hint: raise BENCH_SIM_TIMEOUT, for example:"
        echo "  make benchmark BENCH_MAX_CYCLES=${MAX_CYCLES} BENCH_SIM_TIMEOUT=1200"
        exit 1
    elif [ "${SIM_STATUS}" -ne 0 ]; then
        echo "Error: Benchmark simulation failed"
        exit 1
    fi
else
    "${SIM_ARGS[@]}" > "${SIM_LOG}" 2>&1
fi

echo "========================================"
echo "CoreMark benchmark summary"
echo "========================================"
awk '
    /^SIM_END_REASON = / { print $0 }
    /^Number of executed instruction = / { print $0 }
    /^Number of clock cycles = / { print $0 }
    /^CPI = / { print $0 }
    /^BRANCH_COUNT = / { print $0 }
    /^BRANCH_TAKEN_COUNT = / { print $0 }
    /^BRANCH_PRED_TAKEN_COUNT = / { print $0 }
    /^BRANCH_PRED_CORRECT = / { print $0 }
    /^BRANCH_PRED_WRONG = / { print $0 }
    /^BRANCH_PRED_ACCURACY = / { print $0 }
    /^BRANCH_TAKEN_RATE = / { print $0 }
    /^BRANCH_PRED_TAKEN_RATE = / { print $0 }
    /^BRANCH_MISPREDICT_RATE = / { print $0 }
    /^JAL_COUNT = / { print $0 }
    /^JAL_PRED_CORRECT = / { print $0 }
    /^JAL_PRED_WRONG = / { print $0 }
    /^JAL_PRED_ACCURACY = / { print $0 }
    /^CTRL_PRED_COUNT = / { print $0 }
    /^CTRL_PRED_CORRECT = / { print $0 }
    /^CTRL_PRED_WRONG = / { print $0 }
    /^CTRL_PRED_ACCURACY = / { print $0 }
    /^CTRL_MISPREDICT_RATE = / { print $0 }
' "${SIM_LOG}"
echo "Artifacts: ${BUILD_DIR}"
