.text
.globl _start
_start:
    li x1, 10
    li x2, 20
    add x3, x1, x2
loop:
    j loop
