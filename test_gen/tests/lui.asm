.globl _start
_start:
    lui x1, 0x12345
    j loop
loop:
    j loop