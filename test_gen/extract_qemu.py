#!/usr/bin/env python3
import os
import re
import subprocess
import sys


ELF = sys.argv[1] if len(sys.argv) > 1 else None
OUTPUT = sys.argv[2] if len(sys.argv) > 2 else "qemu_state.txt"
TOOLCHAIN = os.environ.get("TOOLCHAIN", "/home/inori/下载/riscv")
OBJDUMP = f"{TOOLCHAIN}/bin/riscv32-unknown-elf-objdump"
SIM = f"{TOOLCHAIN}/bin/riscv32-unknown-elf-run"

ABI_TO_X = {
    "zero": 0,
    "ra": 1,
    "sp": 2,
    "gp": 3,
    "tp": 4,
    "t0": 5,
    "t1": 6,
    "t2": 7,
    "fp": 8,
    "s0": 8,
    "s1": 9,
    "a0": 10,
    "a1": 11,
    "a2": 12,
    "a3": 13,
    "a4": 14,
    "a5": 15,
    "a6": 16,
    "a7": 17,
    "s2": 18,
    "s3": 19,
    "s4": 20,
    "s5": 21,
    "s6": 22,
    "s7": 23,
    "s8": 24,
    "s9": 25,
    "s10": 26,
    "s11": 27,
    "t3": 28,
    "t4": 29,
    "t5": 30,
    "t6": 31,
}

TRACE_RE = re.compile(r"-wrote\s+([a-zA-Z0-9]+)\s*=\s*(0x[0-9a-fA-F]+|[0-9]+)")


def find_loop_addr(elf_path):
    result = subprocess.run([OBJDUMP, "-d", elf_path], capture_output=True, text=True, check=True)
    fallback_addr = None
    for line in result.stdout.splitlines():
        if "<loop>:" in line:
            addr = line.split(":")[0].split()[0].strip()
            return int(addr, 16)
        match = re.search(r"\bj\s+([0-9a-fA-F]+)\s+<", line)
        if match:
            fallback_addr = int(match.group(1), 16)
    if fallback_addr is not None:
        return fallback_addr
    raise RuntimeError("Could not find terminal loop in disassembly")


def reg_index(name):
    if name.startswith("x") and name[1:].isdigit():
        return int(name[1:])
    return ABI_TO_X.get(name)


def main():
    if not ELF:
        print("Usage: extract_qemu.py <elf_file> [output_file]")
        return 1

    loop_addr = find_loop_addr(ELF)
    result = subprocess.run(
        [
            SIM,
            "--memory-region",
            "0x0,64k",
            "--watch-pc-int",
            f"0x{loop_addr:x}",
            "--trace-register=on",
            ELF,
        ],
        capture_output=True,
        text=True,
    )

    output = result.stdout + result.stderr
    regs = {idx: 0 for idx in range(32)}

    for line in output.splitlines():
        match = TRACE_RE.search(line)
        if not match:
            continue
        idx = reg_index(match.group(1))
        if idx is None:
            continue
        raw_value = match.group(2)
        base = 16 if raw_value.startswith("0x") else 10
        regs[idx] = int(raw_value, base) & 0xFFFFFFFF

    if "program stopped with signal 5" not in output:
        print(output)
        raise RuntimeError("Reference simulator did not stop at loop as expected")

    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write("# Registers\n")
        for idx in range(32):
            f.write(f"x{idx}: 0x{regs[idx]:08x}\n")
        f.write("\n# Data Memory (128 bytes from addr 0)\n")
        for idx in range(128):
            f.write(f"mem[{idx}]: 0x00\n")

    print(f"Extracted reference state to {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
