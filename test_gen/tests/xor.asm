.globl _start
_start:
    li x1, 0xFF
    li x2, 0x0F
    xor x3, x1, x2
    j loop
loop:
    j loop