.globl _start
_start:
    li x1, 10
    li x2, 20
    slt x3, x1, x2
    j loop
loop:
    j loop