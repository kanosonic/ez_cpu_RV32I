#!/bin/bash

ELF=$1
OUTPUT=$2

TOOLCHAIN="${TOOLCHAIN:-/home/inori/下载/riscv}"
GDB=${TOOLCHAIN}/bin/riscv32-unknown-elf-gdb
QEMU=${TOOLCHAIN}/bin/qemu-riscv32

TMPDIR=$(mktemp -d)
PORT=12345

cleanup() {
    kill %1 2>/dev/null || true
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat > "$TMPDIR/gdb_commands.txt" << 'EOF'
set pagination off
set confirm off
# Wait for program to run to infinite loop
# Since we can't easily detect infinite loop, just take snapshot after short delay
shell sleep 0.5
# Print all registers
info registers
# Dump memory (data section, 4KB)
x/1024xb &data
quit
EOF

${QEMU} -g ${PORT} "${ELF}" &
sleep 0.2

${GDB} -batch -x "$TMPDIR/gdb_commands.txt" "${ELF}" > "$TMPDIR/gdb_output.txt" 2>&1 || true

{
    echo "# Registers"
    grep -E "^(\$[a-z0-9]+|pc)" "$TMPDIR/gdb_output.txt" | head -33 || true
    echo ""
    echo "# Data Memory"
    grep -E "^0x" "$TMPDIR/gdb_output.txt" | tail -1024 || true
} > "${OUTPUT}"
