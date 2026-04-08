.globl _start
_start:
    li x1, 0xF0
    li x2, 0x0F
    or x3, x1, x2
    j loop
loop:
    j loop
