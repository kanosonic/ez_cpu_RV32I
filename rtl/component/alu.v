`include "define.v"
module alu #(
        parameter DATAWIDTH = 32
    ) (
        input  [DATAWIDTH - 1:0] A,
        input  [DATAWIDTH - 1:0] B,
        input  [3:0]			ALU_Ctrl,

        output reg [DATAWIDTH - 1:0] Result,
        //output Overflow,
        output reg Branch_cond
    );
    wire[4:0] shamt;	//offset for shift
    assign shamt = B [4:0];

    //for result
    always @(*) begin
        case (ALU_Ctrl)
            `ALU_OP_AND:
                Result = A & B;
            `ALU_OP_OR:
                Result = A | B;
            `ALU_OP_ADD:
                Result = A + B;
            `ALU_OP_SUB:
                Result = A - B;
            `ALU_OP_SLL:
                Result = A << shamt;
            `ALU_OP_SLT:
                Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
            `ALU_OP_SLTU:
                Result = (A < B) ? 32'd1 : 32'd0;
            `ALU_OP_XOR:
                Result = A ^ B;
            `ALU_OP_SRL:
                Result = A >> shamt;
            `ALU_OP_SRA:
                Result = $signed(A) >>> shamt;
            default:
                Result = 'd0;
        endcase

    end

    //for branch
    always @(*) begin
        case (ALU_Ctrl)
            `ALU_OP_BEQ:
                Branch_cond = (A == B);
            `ALU_OP_BNE:
                Branch_cond = (A != B);
            `ALU_OP_BLT:
                Branch_cond = ($signed(A) <  $signed(B));
            `ALU_OP_BGE:
                Branch_cond = ($signed(A) >= $signed(B));
            `ALU_OP_BLTU:
                Branch_cond = (A <  B);
            `ALU_OP_BGEU:
                Branch_cond = (A >= B);
            default:
                Branch_cond = 'd0;
        endcase
    end
endmodule
