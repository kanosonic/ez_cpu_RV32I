.text
.globl _start
_start:
    li x1, 0
    li x2, 0x12345678
    sw x2, 0(x1)
    lw x3, 0(x1)
    j loop
loop:
    j loop
