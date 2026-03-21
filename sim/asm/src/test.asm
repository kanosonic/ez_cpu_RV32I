# rv32i_jalr_test.asm
.text
.global _start
_start:
    
    addi x1, x0, 10   
    addi x2, x0, 0    
    
    la   x3, jalr_target
    
   
    jalr x4, x3, 0    
    
   
    add  x2, x2, x1  
    
loop:
    j loop           


jalr_target:
    addi x2, x2, 5    
    jr   x4           