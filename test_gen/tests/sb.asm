.text
.globl _start
_start:
    li x1, 0
    li x2, 0xAA
    sb x2, 0(x1)
    lbu x3, 0(x1)
    j loop
loop:
    j loop
