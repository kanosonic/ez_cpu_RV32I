.globl _start
_start:
    li x1, 1
    slli x2, x1, 4
    j loop
loop:
    j loop