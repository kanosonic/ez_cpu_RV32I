//use instruction in ID stage to generate control signals
`include "define.v"
module controller(
        input [31:0] id_Inst,

        output reg id_RegWrite,
        output reg [1:0] id_WTR,    //Where to Reg: Mem(00), ALU(01), PC4(10), Imm(11)(for LUI)

        output reg [2:0] id_MemRead,
        output reg [1:0] id_MemWrite,

        output reg [1:0] id_ALU_Op,
        output reg id_ALUSrcA,	//for deciding whether the first ALU operand is from constant Rs1(0) or  PC(1)(for AUIPC and JAL)
        output reg id_ALUSrcB,	//for deciding whether the second ALU operand is from Rs2(0) or imm(1)

        output reg id_Branch,

        output reg id_JALR,	// for JALR
        output reg id_JAL  //for JAL

    );
    wire [6:0] opcode = id_Inst[6:0];
    wire [2:0] funct3 = id_Inst[14:12];
    always @(*) begin
        case(opcode)
            // R-type（add/sub/sll/slt/sltu/xor/srl/sra/or/and）
            `OPCODE_ALUR: begin
                id_RegWrite = 1'b1;
                id_WTR      = `WTR_ALU; //from alu
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b10;
                id_ALUSrcA  = `ALUSrcA_RS1;	// rs1
                id_ALUSrcB  = `ALUSrcB_RS2;	// rs2
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;
            end

            // I-type（addi/slti/sltiu/xori/ori/andi/slli/srli/srai）
            `OPCODE_ALUI: begin
                id_RegWrite = 1'b1;
                id_WTR      = `WTR_ALU; //from alu
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = (funct3 == 3'b000) ? 2'b00 : 2'b10;
                id_ALUSrcA  = `ALUSrcA_RS1;	// rs1
                id_ALUSrcB  = `ALUSrcB_IMM;	// imm
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;
            end

            // Load（lb/lh/lw/lbu/lhu）
            `OPCODE_LOAD: begin
                id_RegWrite = 1'b1;
                id_WTR      = `WTR_MEM; //from mem
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b00;
                id_ALUSrcA  = `ALUSrcA_RS1;	// rs1
                id_ALUSrcB  = `ALUSrcB_IMM;	// imm for offset
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;

                case (funct3)
                    `LB_FUNCT3:
                        id_MemRead = `MEMREAD_LB;
                    `LH_FUNCT3:
                        id_MemRead = `MEMREAD_LH;
                    `LW_FUNCT3:
                        id_MemRead = `MEMREAD_LW;
                    `LBU_FUNCT3:
                        id_MemRead = `MEMREAD_LBU;
                    `LHU_FUNCT3:
                        id_MemRead = `MEMREAD_LHU;
                    default:
                        id_MemRead = `MEMREAD_NOP;
                endcase
            end

            // Store（sb/sh/sw）
            `OPCODE_STORE: begin
                id_RegWrite = 1'b0;
                id_WTR      = 2'b00; //don't care
                id_MemRead  = `MEMREAD_NOP;
                id_ALU_Op   = 2'b00;
                id_ALUSrcA  = `ALUSrcA_RS1;	// rs1
                id_ALUSrcB  = `ALUSrcB_IMM;	// imm for offset
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;

                case (funct3)
                    `SB_FUNCT3:
                        id_MemWrite = `MEMWRITE_SB;
                    `SH_FUNCT3:
                        id_MemWrite = `MEMWRITE_SH;
                    `SW_FUNCT3:
                        id_MemWrite = `MEMWRITE_SW;
                    default:
                        id_MemWrite = `MEMWRITE_NOP;
                endcase
            end

            // Branch（beq/bne/blt/bge/bltu/bgeu）
            `OPCODE_BRANCH: begin
                id_RegWrite = 1'b0;
                id_WTR      = 2'b00; //don't care
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b01;
                id_ALUSrcA  = `ALUSrcA_RS1;	// rs1
                id_ALUSrcB  = `ALUSrcB_RS2;	// rs2
                id_Branch   = 1'b1;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;
            end

            // LUI
            `OPCODE_LUI: begin
                id_RegWrite = 1'b1;
                id_WTR      = `WTR_IMM;
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b10; // don't care
                id_ALUSrcA  = 1'b0;	// don't care
                id_ALUSrcB  = 1'b0;	// don't care
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;
            end

            // AUIPC（PC + imm）
            `OPCODE_AUIPC: begin
                id_RegWrite = 1'b1;
                id_WTR      = `WTR_ALU;
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b00;
                id_ALUSrcA  = `ALUSrcA_PC;	// rs1
                id_ALUSrcB  = `ALUSrcB_IMM;	// rs2
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;
            end

            // JAL（无条件跳转并链接）
            `OPCODE_JAL: begin
                id_RegWrite = 1'b1;
                id_WTR      = `WTR_PC4;
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b00;
                id_ALUSrcA  = 1'b0;	// don't care
                id_ALUSrcB  = 1'b0;	// don't care
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b1;
            end

            // JALR指令（寄存器间接跳转并链接）
            `OPCODE_JALR: begin
                id_RegWrite = 1'b1;
                id_WTR      = `WTR_PC4;
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b00;
                id_ALUSrcA  = `ALUSrcA_RS1; 	// rs1
                id_ALUSrcB  = `ALUSrcB_IMM; 	// imm
                id_Branch   = 1'b0;
                id_JALR     = 1'b1;
                id_JAL      = 1'b0;
            end

            // SYSTEM（ecall/ebreak）
            `OPCODE_SYSTEM: begin
                id_RegWrite = 1'b0;
                id_WTR      = 2'b00;
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b10;
                id_ALUSrcA  = 1'b0;	// rs1
                id_ALUSrcB  = 1'b0;	// rs2
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;
            end

            // Invalid/Unsupported Instructions
            default: begin
                id_RegWrite = 1'b0;
                id_WTR      = 2'b00;
                id_MemRead  = `MEMREAD_NOP;
                id_MemWrite = `MEMWRITE_NOP;
                id_ALU_Op   = 2'b00;
                id_ALUSrcA  = 1'b0;	// rs1
                id_ALUSrcB  = 1'b0;	// rs2
                id_Branch   = 1'b0;
                id_JALR     = 1'b0;
                id_JAL      = 1'b0;
            end
        endcase
    end
endmodule //control
