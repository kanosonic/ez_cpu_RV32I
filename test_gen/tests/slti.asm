.globl _start
_start:
    li x1, 10
    slti x2, x1, 20
    j loop
loop:
    j loop