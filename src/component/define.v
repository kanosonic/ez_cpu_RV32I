`define ALU_OP_ADD      4'b0000
`define ALU_OP_SUB      4'b1000
`define ALU_OP_SLL      4'b0001
`define ALU_OP_SLT      4'b0010
`define ALU_OP_SLTU     4'b0011
`define ALU_OP_XOR      4'b0100
`define ALU_OP_SRL      4'b0101
`define ALU_OP_SRA      4'b1101
`define ALU_OP_OR       4'b0110
`define ALU_OP_AND      4'b0111

`define ALU_OP_BEQ      4'b1001
`define ALU_OP_BNE      4'b1010
`define ALU_OP_BLT      4'b1011
`define ALU_OP_BGE      4'b1100
`define ALU_OP_BLTU     4'b1101
`define ALU_OP_BGEU     4'b1110

`define ALU_OP_XXX      4'b1111


`define BEQ_FUNCT3      3'b000
`define BNE_FUNCT3      3'b001
`define BLT_FUNCT3      3'b100
`define BGE_FUNCT3      3'b101
`define BLTU_FUNCT3     3'b110
`define BGEU_FUNCT3     3'b111

`define LB_FUNCT3		3'b000
`define LH_FUNCT3		3'b001
`define LW_FUNCT3		3'b010
`define LBU_FUNCT3		3'b100
`define LHU_FUNCT3		3'b101

`define SB_FUNCT3		3'b000
`define SH_FUNCT3		3'b001
`define SW_FUNCT3		3'b010

`define OPCODE_LUI             7'b01_101_11
`define OPCODE_AUIPC           7'b00_101_11
`define OPCODE_JAL             7'b11_011_11
`define OPCODE_JALR            7'b11_001_11
`define OPCODE_BRANCH          7'b11_000_11
`define OPCODE_LOAD            7'b00_000_11
`define OPCODE_STORE           7'b01_000_11
`define OPCODE_ALUI            7'b00_100_11
`define OPCODE_ALUR            7'b01_100_11
`define OPCODE_FENCE           7'b00_011_11
`define OPCODE_SYSTEM          7'b11_100_11

`define WTR_MEM		2'b00
`define WTR_ALU		2'b01
`define WTR_PC4		2'b10
`define WTR_IMM		2'b11

`define ALUSrcA_RS1 	1'b0
`define ALUSrcA_PC  	1'b1

`define ALUSrcB_RS2 	1'b0
`define ALUSrcB_IMM  	1'b1

`define MEMREAD_NOP		3'b000
`define MEMREAD_LB		3'b001
`define MEMREAD_LH		3'b010
`define MEMREAD_LW		3'b011
`define MEMREAD_LBU		3'b100
`define MEMREAD_LHU		3'b101


`define MEMWRITE_NOP 	2'b00
`define MEMWRITE_SB 	2'b01
`define MEMWRITE_SH 	2'b10
`define MEMWRITE_SW 	2'b11


`define FORWARD_A_EX 	2'b10
`define FORWARD_A_MEM 	2'b01
`define FORWARD_A_NOP 	2'b00

`define FORWARD_B_EX 	2'b10
`define FORWARD_B_MEM 	2'b01
`define FORWARD_B_NOP 	2'b00
