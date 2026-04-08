#!/usr/bin/env python3
import sys

VCD_FILE = sys.argv[1]
OUTPUT_FILE = sys.argv[2]

def parse_vcd_to_registers(vcd_path, output_path):
    regs = {}
    
    with open(vcd_path, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    reg_pattern = re.compile(r'b([01]+)\s+cpu_tb\.u_cpu\.u_reg_file\.reg_data\[(\d+)\]')
    reg_values = {}
    
    for line in lines:
        reg_match = reg_pattern.search(line)
        if reg_match:
            value = reg_match.group(1)
            idx = int(reg_match.group(2))
            reg_values[idx] = value
    
    with open(output_path, 'w') as f:
        f.write("# Registers\n")
        for i in range(32):
            if i in reg_values:
                val = reg_values[i][::-1]
                f.write(f"x{i}: 0x{int(val, 2):08x}\n")
            else:
                f.write(f"x{i}: 0x00000000\n")
        
        f.write("\n# Data Memory (4KB)\n")
        for i in range(4096):
            f.write(f"mem[{i}]: 0x00\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: extract_cpu.py <vcd_file> <output_file>")
        sys.exit(1)
    
    vcd_file = sys.argv[1]
    output_file = sys.argv[2]
    parse_vcd_to_registers(vcd_file, output_file)
    print(f"Extracted CPU state to {output_file}")