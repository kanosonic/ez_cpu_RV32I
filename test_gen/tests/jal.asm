.globl _start
_start:
    jal x1, label
    li x2, 0xFF
label:
    li x3, 0x11
    j loop
loop:
    j loop