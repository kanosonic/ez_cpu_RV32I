.globl _start
_start:
    li x1, 30
    li x2, 20
    sub x3, x1, x2
    j loop
loop:
    j loop