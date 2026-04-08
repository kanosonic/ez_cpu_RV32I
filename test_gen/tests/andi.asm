.globl _start
_start:
    li x1, 0xFF
    andi x2, x1, 0xF0
    j loop
loop:
    j loop