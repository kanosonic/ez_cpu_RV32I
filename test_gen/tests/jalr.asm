.globl _start
_start:
    auipc x1, 0
    addi x1, x1, 12
    jalr x2, x1, 0
    li x3, 0
    j loop
target:
    li x3, 1
    j loop
loop:
    j loop
