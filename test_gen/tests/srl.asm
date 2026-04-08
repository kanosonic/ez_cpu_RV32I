.globl _start
_start:
    li x1, 0x10
    li x2, 2
    srl x3, x1, x2
    j loop
loop:
    j loop