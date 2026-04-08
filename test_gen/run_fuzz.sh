#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

FUZZ_LOOPS="${FUZZ_LOOPS:-1000}"
FUZZ_SEED="${FUZZ_SEED:-1}"
FUZZ_STEPS="${FUZZ_STEPS:-32}"
TOTAL_CPI="0"

echo "========================================"
echo "RV32I Differential Fuzz Test"
echo "========================================"
echo "loops=${FUZZ_LOOPS} seed=${FUZZ_SEED} steps=${FUZZ_STEPS}"

for ((idx = 0; idx < FUZZ_LOOPS; idx++)); do
    seed=$((FUZZ_SEED + idx))
    run_name=$(printf "fuzz_%05d" "$((idx + 1))")
    build_dir="${PROJECT_DIR}/test_gen/build/${run_name}"
    asm_path="${build_dir}/${run_name}.asm"
    metrics_path="${build_dir}/cpu_metrics.txt"

    mkdir -p "${build_dir}"

    echo ""
    echo "Fuzz ${idx}/${FUZZ_LOOPS}: ${run_name} seed=${seed}"

    python3 "${SCRIPT_DIR}/generate_fuzz.py" \
        --seed "${seed}" \
        --steps "${FUZZ_STEPS}" \
        --output "${asm_path}"

    if ! ASM_FILE_OVERRIDE="${asm_path}" RUN_NAME_OVERRIDE="${run_name}" "${SCRIPT_DIR}/run_single.sh" fuzz; then
        echo ""
        echo "Fuzz failed at iteration $((idx + 1)) with seed=${seed}"
        echo "Repro:"
        echo "  make fuzz FUZZ_LOOPS=1 FUZZ_SEED=${seed} FUZZ_STEPS=${FUZZ_STEPS}"
        echo "Artifacts:"
        echo "  ${build_dir}"
        exit 1
    fi

    if [ ! -f "${metrics_path}" ]; then
        echo "Error: Missing CPI metrics at ${metrics_path}"
        exit 1
    fi

    cpi_value="$(awk -F= '/^CPI=/{print $2}' "${metrics_path}" | tail -n 1)"
    if [ -z "${cpi_value}" ]; then
        echo "Error: Failed to parse CPI from ${metrics_path}"
        exit 1
    fi

    TOTAL_CPI="$(awk -v sum="${TOTAL_CPI}" -v cpi="${cpi_value}" 'BEGIN { printf "%.6f", sum + cpi }')"
    echo "Differential fuzz CPI: ${cpi_value}"
done

AVERAGE_CPI="$(awk -v sum="${TOTAL_CPI}" -v loops="${FUZZ_LOOPS}" 'BEGIN { if (loops == 0) printf "0.000000"; else printf "%.6f", sum / loops }')"

echo ""
echo "========================================"
echo "Differential fuzz summary: ${FUZZ_LOOPS}/${FUZZ_LOOPS} PASS"
echo "Average CPI: ${AVERAGE_CPI}"
echo "========================================"
