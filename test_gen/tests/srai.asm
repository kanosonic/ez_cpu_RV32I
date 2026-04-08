.globl _start
_start:
    li x1, 0x80
    srai x2, x1, 3
    j loop
loop:
    j loop
