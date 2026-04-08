.globl _start
_start:
    auipc x1, 0x12345
    j loop
loop:
    j loop