#!/usr/bin/env python3
import re
import sys


REG_RE = re.compile(r"^x(\d+):\s*0x([0-9a-fA-F]+)\s*$")
MEM_RE = re.compile(r"^mem\[(\d+)\]:\s*0x([0-9a-fA-F]+)\s*$")


def parse_state(path):
    regs = {}
    mem = {}
    with open(path, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            reg_match = REG_RE.match(line)
            if reg_match:
                regs[int(reg_match.group(1))] = int(reg_match.group(2), 16)
                continue
            mem_match = MEM_RE.match(line)
            if mem_match:
                mem[int(mem_match.group(1))] = int(mem_match.group(2), 16)
    return regs, mem


def main():
    if len(sys.argv) != 3:
        print("Usage: compare_state.py <cpu_state> <ref_state>")
        return 2

    cpu_regs, cpu_mem = parse_state(sys.argv[1])
    ref_regs, ref_mem = parse_state(sys.argv[2])

    mismatches = []
    for reg_idx in range(32):
        cpu_val = cpu_regs.get(reg_idx, 0)
        ref_val = ref_regs.get(reg_idx, 0)
        if cpu_val != ref_val:
            mismatches.append(
                f"x{reg_idx}: cpu=0x{cpu_val:08x}, ref=0x{ref_val:08x}"
            )

    if mismatches:
        print("State mismatch:")
        for item in mismatches[:32]:
            print(item)
        if len(mismatches) > 32:
            print(f"... {len(mismatches) - 32} more mismatches")
        return 1

    print("State match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
