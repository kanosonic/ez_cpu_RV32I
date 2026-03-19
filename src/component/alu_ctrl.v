`include "define.v"
module ALU_Ctrl(
        input [1:0] ALU_Op,
        input [6:0] funct7,
        input [2:0] funct3,

        output reg [3:0] ALU_Ctrl

    );

    wire funct7b5 = funct7[5];

    // output is declared as reg above, no separate reg needed
    always @(ALU_Op, funct7, funct3) begin
        case (ALU_Op)
            2'b00:
                ALU_Ctrl = `ALU_OP_ADD; // Load/Store/LUI/AUIPC/ADDI/JALR/: ADD
            2'b01:
                case (funct3)
                    `BEQ_FUNCT3:
                        ALU_Ctrl = `ALU_OP_BEQ;
                    `BNE_FUNCT3:
                        ALU_Ctrl = `ALU_OP_BNE;
                    `BLT_FUNCT3:
                        ALU_Ctrl = `ALU_OP_BLT;
                    `BGE_FUNCT3:
                        ALU_Ctrl = `ALU_OP_BGE;
                    `BLTU_FUNCT3:
                        ALU_Ctrl = `ALU_OP_BLTU;
                    `BGEU_FUNCT3:
                        ALU_Ctrl = `ALU_OP_BGEU;
                    default:
                        ALU_Ctrl = `ALU_OP_XXX;
                endcase
            2'b10: begin // R-Type or I-Type (depending on ALUSrc)
                case (funct3)
                    3'b000:
                        ALU_Ctrl = (funct7b5) ? `ALU_OP_SUB : `ALU_OP_ADD; // SUB/ADD
                    3'b001:
                        ALU_Ctrl = `ALU_OP_SLL;
                    3'b010:
                        ALU_Ctrl = `ALU_OP_SLT;
                    3'b011:
                        ALU_Ctrl = `ALU_OP_SLTU;
                    3'b100:
                        ALU_Ctrl = `ALU_OP_XOR;
                    3'b101:
                        ALU_Ctrl = (funct7b5) ? `ALU_OP_SRA : `ALU_OP_SRL;
                    3'b110:
                        ALU_Ctrl = `ALU_OP_OR; // OR
                    3'b111:
                        ALU_Ctrl = `ALU_OP_AND; // AND

                    default:
                        ALU_Ctrl = `ALU_OP_XXX;
                endcase
            end
            default:
                ALU_Ctrl = `ALU_OP_XXX;
        endcase
    end

endmodule

