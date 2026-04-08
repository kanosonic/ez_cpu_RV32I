.globl _start
_start:
    li x1, 0xF0
    ori x2, x1, 0x0F
    j loop
loop:
    j loop