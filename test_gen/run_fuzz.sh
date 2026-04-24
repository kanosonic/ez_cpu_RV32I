#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

FUZZ_LOOPS="${FUZZ_LOOPS:-1000}"
FUZZ_SEED="${FUZZ_SEED:-1}"
FUZZ_STEPS="${FUZZ_STEPS:-32}"
FUZZ_JOBS="${FUZZ_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
TOTAL_CPI="0"
TOTAL_BRANCH_COUNT=0
TOTAL_BRANCH_PRED_CORRECT=0
SHARED_SIM_BIN="${PROJECT_DIR}/build/cpu_fuzz_sim.vvp"
STATUS_ROOT="${PROJECT_DIR}/test_gen/build/fuzz_status"

render_progress() {
    local completed
    local percent
    local width=40
    local filled
    local empty
    local filled_bar
    local empty_bar

    if [ "${FUZZ_LOOPS}" -le 0 ]; then
        return
    fi

    completed="$(find "${STATUS_ROOT}" -maxdepth 1 -name '*.status' -type f | wc -l)"
    percent=$((completed * 100 / FUZZ_LOOPS))
    filled=$((completed * width / FUZZ_LOOPS))
    empty=$((width - filled))

    printf -v filled_bar '%*s' "${filled}" ''
    filled_bar="${filled_bar// /#}"
    printf -v empty_bar '%*s' "${empty}" ''
    empty_bar="${empty_bar// /-}"

    printf '\rFuzz progress [%s%s] %3d%% (%d/%d)' \
        "${filled_bar}" "${empty_bar}" "${percent}" "${completed}" "${FUZZ_LOOPS}"
}

run_fuzz_case() {
    local idx="$1"
    local seed="$2"
    local run_name
    local build_dir
    local asm_path
    local metrics_path
    local status_path
    local cpi_value
    local branch_count
    local branch_pred_correct
    local branch_pred_accuracy

    run_name=$(printf "fuzz_%05d" "$((idx + 1))")
    build_dir="${PROJECT_DIR}/test_gen/build/${run_name}"
    asm_path="${build_dir}/${run_name}.asm"
    metrics_path="${build_dir}/cpu_metrics.txt"
    status_path="${STATUS_ROOT}/${run_name}.status"

    mkdir -p "${build_dir}" "${STATUS_ROOT}"

    {
        echo ""
        echo "Fuzz ${idx}/${FUZZ_LOOPS}: ${run_name} seed=${seed}"

        python3 "${SCRIPT_DIR}/generate_fuzz.py" \
            --seed "${seed}" \
            --steps "${FUZZ_STEPS}" \
            --output "${asm_path}"

        if ! ASM_FILE_OVERRIDE="${asm_path}" \
            RUN_NAME_OVERRIDE="${run_name}" \
            SIM_BIN_OVERRIDE="${SHARED_SIM_BIN}" \
            STATE_FILE_OVERRIDE="${build_dir}/cpu_state.txt" \
            DISABLE_VCD=1 \
            "${SCRIPT_DIR}/run_single.sh" fuzz; then
            cat > "${status_path}" <<EOF
FAIL
seed=${seed}
run_name=${run_name}
build_dir=${build_dir}
repro=make fuzz FUZZ_LOOPS=1 FUZZ_SEED=${seed} FUZZ_STEPS=${FUZZ_STEPS}
EOF
            exit 1
        fi

        if [ ! -f "${metrics_path}" ]; then
            cat > "${status_path}" <<EOF
FAIL
seed=${seed}
run_name=${run_name}
build_dir=${build_dir}
reason=missing_metrics
EOF
            exit 1
        fi

        cpi_value="$(awk -F= '/^CPI=/{print $2}' "${metrics_path}" | tail -n 1)"
        if [ -z "${cpi_value}" ]; then
            cat > "${status_path}" <<EOF
FAIL
seed=${seed}
run_name=${run_name}
build_dir=${build_dir}
reason=missing_cpi
EOF
            exit 1
        fi

        branch_count="$(awk -F= '/^BRANCH_COUNT=/{print $2}' "${metrics_path}" | tail -n 1)"
        branch_pred_correct="$(awk -F= '/^BRANCH_PRED_CORRECT=/{print $2}' "${metrics_path}" | tail -n 1)"
        branch_pred_accuracy="$(awk -F= '/^BRANCH_PRED_ACCURACY=/{print $2}' "${metrics_path}" | tail -n 1)"
        if [ -z "${branch_count}" ] || [ -z "${branch_pred_correct}" ] || [ -z "${branch_pred_accuracy}" ]; then
            cat > "${status_path}" <<EOF
FAIL
seed=${seed}
run_name=${run_name}
build_dir=${build_dir}
reason=missing_branch_metrics
EOF
            exit 1
        fi

        cat > "${status_path}" <<EOF
PASS
seed=${seed}
run_name=${run_name}
build_dir=${build_dir}
cpi=${cpi_value}
branch_count=${branch_count}
branch_pred_correct=${branch_pred_correct}
branch_pred_accuracy=${branch_pred_accuracy}
EOF

        # Keep failure artifacts for repro, but delete successful fuzz outputs
        # immediately to avoid filling the workspace with generated files.
        rm -rf "${build_dir}"
    } < /dev/null > "${build_dir}/fuzz.log" 2>&1
}

echo "========================================"
echo "RV32I Differential Fuzz Test"
echo "========================================"
echo "loops=${FUZZ_LOOPS} seed=${FUZZ_SEED} steps=${FUZZ_STEPS} jobs=${FUZZ_JOBS}"

mkdir -p "${PROJECT_DIR}/build" "${PROJECT_DIR}/test_gen/build"
if [ -d "${STATUS_ROOT}" ]; then
    find "${STATUS_ROOT}" -mindepth 1 -delete
    rmdir "${STATUS_ROOT}" 2>/dev/null || true
fi
mkdir -p "${STATUS_ROOT}"

echo "Compiling shared simulation binary..."
iverilog -g2012 -I "${PROJECT_DIR}/rtl" -I "${PROJECT_DIR}/rtl/component" \
    -o "${SHARED_SIM_BIN}" \
    "${PROJECT_DIR}/testbench/cpu_tb.v" \
    "${PROJECT_DIR}/rtl/core/cpu.v" \
    "${PROJECT_DIR}/rtl/component/"*.v

render_progress

for ((idx = 0; idx < FUZZ_LOOPS; idx++)); do
    seed=$((FUZZ_SEED + idx))
    run_fuzz_case "${idx}" "${seed}" &

    while [ "$(jobs -rp | wc -l)" -ge "${FUZZ_JOBS}" ]; do
        if ! wait -n; then
            :
        fi
        render_progress
    done
done

failed=0
while [ "$(jobs -rp | wc -l)" -gt 0 ]; do
    if ! wait -n; then
        failed=1
    fi
    render_progress
done

if [ "${FUZZ_LOOPS}" -gt 0 ]; then
    echo ""
fi

FAIL_LIST="${STATUS_ROOT}/failures.txt"
if find "${STATUS_ROOT}" -name '*.status' -type f | xargs -r grep -l '^FAIL$' > "${FAIL_LIST}"; then
    if [ -s "${FAIL_LIST}" ]; then
        failed=1
    fi
fi

if [ "${failed}" -ne 0 ]; then
    failure_file="$(sort "${FAIL_LIST}" 2>/dev/null | head -n 1 || true)"
    if [ -n "${failure_file}" ]; then
        seed="$(awk -F= '/^seed=/{print $2}' "${failure_file}")"
        run_name="$(awk -F= '/^run_name=/{print $2}' "${failure_file}")"
        build_dir="$(awk -F= '/^build_dir=/{print $2}' "${failure_file}")"
        repro="$(awk -F= '/^repro=/{print $2}' "${failure_file}")"
        echo ""
        echo "Fuzz failed for ${run_name} with seed=${seed}"
        [ -n "${repro}" ] && echo "Repro: ${repro}"
        [ -n "${build_dir}" ] && echo "Artifacts: ${build_dir}"
    else
        echo "Error: Fuzz failed but no failure record was found"
    fi
    exit 1
fi

pass_count=0
for ((idx = 0; idx < FUZZ_LOOPS; idx++)); do
    run_name=$(printf "fuzz_%05d" "$((idx + 1))")
    status_path="${STATUS_ROOT}/${run_name}.status"

    if [ ! -f "${status_path}" ]; then
        echo "Error: Missing fuzz status at ${status_path}"
        exit 1
    fi

    cpi_value="$(awk -F= '/^cpi=/{print $2}' "${status_path}" | tail -n 1)"
    if [ -z "${cpi_value}" ]; then
        echo "Error: Failed to parse CPI from ${status_path}"
        exit 1
    fi

    branch_count="$(awk -F= '/^branch_count=/{print $2}' "${status_path}" | tail -n 1)"
    branch_pred_correct="$(awk -F= '/^branch_pred_correct=/{print $2}' "${status_path}" | tail -n 1)"
    if [ -z "${branch_count}" ] || [ -z "${branch_pred_correct}" ]; then
        echo "Error: Failed to parse branch prediction metrics from ${status_path}"
        exit 1
    fi

    TOTAL_CPI="$(awk -v sum="${TOTAL_CPI}" -v cpi="${cpi_value}" 'BEGIN { printf "%.6f", sum + cpi }')"
    TOTAL_BRANCH_COUNT=$((TOTAL_BRANCH_COUNT + branch_count))
    TOTAL_BRANCH_PRED_CORRECT=$((TOTAL_BRANCH_PRED_CORRECT + branch_pred_correct))
    pass_count=$((pass_count + 1))
done

AVERAGE_CPI="$(awk -v sum="${TOTAL_CPI}" -v loops="${FUZZ_LOOPS}" 'BEGIN { if (loops == 0) printf "0.000000"; else printf "%.6f", sum / loops }')"
BRANCH_PRED_ACCURACY="$(awk -v correct="${TOTAL_BRANCH_PRED_CORRECT}" -v total="${TOTAL_BRANCH_COUNT}" 'BEGIN { if (total == 0) printf "0.000000"; else printf "%.6f", 100.0 * correct / total }')"

find "${STATUS_ROOT}" -mindepth 1 -delete
rmdir "${STATUS_ROOT}" 2>/dev/null || true

echo ""
echo "========================================"
echo "Differential fuzz summary: ${pass_count}/${FUZZ_LOOPS} PASS"
echo "Average CPI: ${AVERAGE_CPI}"
echo "BRANCH prediction accuracy: ${BRANCH_PRED_ACCURACY}% (${TOTAL_BRANCH_PRED_CORRECT}/${TOTAL_BRANCH_COUNT})"
echo "========================================"
