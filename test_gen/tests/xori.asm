.globl _start
_start:
    li x1, 0xFF
    xori x2, x1, 0x0F
    j loop
loop:
    j loop