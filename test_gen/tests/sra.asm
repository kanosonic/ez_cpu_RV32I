.globl _start
_start:
    li x1, 0x80
    li x2, 3
    sra x3, x1, x2
    j loop
loop:
    j loop