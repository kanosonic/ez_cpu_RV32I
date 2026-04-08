#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

INSTR_LIST="${SCRIPT_DIR}/instr_list.txt"

if [ -f "${INSTR_LIST}" ]; then
    INSTRUCTIONS=$(cat "${INSTR_LIST}")
else
    echo "Error: instr_list.txt not found"
    exit 1
fi

PASS=0
FAIL=0
FAILED_INSTR=""

echo "========================================"
echo "RV32I Differential Test (37 instructions)"
echo "========================================"

for INSTR in ${INSTRUCTIONS}; do
    echo ""
    echo "Testing: ${INSTR} ..."
    
    if "${SCRIPT_DIR}/run_single.sh" "${INSTR}"; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
        FAILED_INSTR="${FAILED_INSTR} ${INSTR}"
    fi
done

echo ""
echo "========================================"
echo "Summary: ${PASS}/37 PASS, ${FAIL}/37 FAIL"
echo "========================================"

if [ ${FAIL} -gt 0 ]; then
    echo "Failed: ${FAILED_INSTR}"
    exit 1
fi

exit 0