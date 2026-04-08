.globl _start
_start:
    li x1, 0x10
    srli x2, x1, 2
    j loop
loop:
    j loop