.text
.globl _start
_start:
    li x1, 0
    li x2, 0x1234
    sh x2, 0(x1)
    lh x3, 0(x1)
    j loop
loop:
    j loop
