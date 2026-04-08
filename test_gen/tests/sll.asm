.globl _start
_start:
    li x1, 1
    li x2, 4
    sll x3, x1, x2
    j loop
loop:
    j loop