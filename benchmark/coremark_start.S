.section .text.start
.globl _start

_start:
    lui sp, %hi(__stack_top)
    addi sp, sp, %lo(__stack_top)
    call main

loop:
    addi x0, x0, 0
    j loop
