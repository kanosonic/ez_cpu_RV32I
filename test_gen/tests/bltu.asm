.globl _start
_start:
    li x1, 10
    li x2, 20
    bltu x1, x2, label1
    li x3, 0
    j end
label1:
    li x3, 1
end:
    j loop
loop:
    j loop