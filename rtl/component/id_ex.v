//pipeline regs for ID/EX
module id_ex(
	input clk,
	input rstn,
	input flush,


	//from Imm_gen
	input [31:0] id_Imm,

	//from regfile
	input [31:0] id_Data1,
	input [31:0] id_Data2,

	//from control unit
	input id_RegWrite,
	input [1:0] id_WTR,   
	input [2:0] id_MemRead,
	input [1:0] id_MemWrite,
	input [3:0] id_ALU_Ctrl,
	input id_ALUSrcA,	
	input id_ALUSrcB,	
	input id_Branch,
	input id_JAL,
	input id_JALR,

	//from if_id
	input [4:0]  id_Rs1,
	input [4:0]  id_Rs2,
	input [4:0]  id_Rd,
	input [31:0] id_PC,
	input [31:0] id_PC4,
	input [31:0] id_PCImm,
	input id_pred_branch_taken,


	output reg [31:0] ex_Imm,

	output reg [31:0] ex_Data1,
	output reg [31:0] ex_Data2,

	output reg ex_RegWrite,
	output reg [1:0] ex_WTR,   
	output reg [2:0] ex_MemRead,
	output reg [1:0] ex_MemWrite,
	output reg [3:0] ex_ALU_Ctrl,
	output reg ex_ALUSrcA,	
	output reg ex_ALUSrcB,	
	output reg ex_Branch,
	output reg ex_JAL,
	output reg ex_JALR,

	output reg [4:0] ex_Rs1,
	output reg [4:0] ex_Rs2,
	output reg [4:0] ex_Rd,
	output reg [31:0] ex_PC,
	output reg [31:0] ex_PCImm,
	output reg [31:0] ex_PC4,
	output reg ex_pred_branch_taken
	
);

	always @(posedge clk) begin
		if(!rstn || flush)begin
			ex_Imm		<=	'd0;
			ex_Data1	<=	'd0;
			ex_Data2	<=	'd0;
			ex_RegWrite	<=	'd0;
			ex_WTR   	<=	'd0;
			ex_MemRead	<=	'd0;
			ex_MemWrite	<=	'd0;
			ex_ALU_Ctrl	<=	'd0;
			ex_ALUSrcA	<=	'd0;		
			ex_ALUSrcB	<=	'd0;	
			ex_Branch	<=	'd0;
			ex_JAL		<=	'd0;
			ex_JALR		<=	'd0;
			ex_Rs1		<=	'd0;
			ex_Rs2		<=	'd0;
			ex_Rd		<=	'd0;
			ex_PC		<=	'd0;
			ex_PCImm 	<=	'd0;
			ex_PC4		<=	'd0;
			ex_pred_branch_taken <= 1'b0;												
		end else begin
			ex_Imm		<=	id_Imm		;
			ex_Data1	<=	id_Data1	;
			ex_Data2	<=	id_Data2	;
			ex_RegWrite	<=	id_RegWrite	;
			ex_WTR   	<=	id_WTR   	;
			ex_MemRead	<=	id_MemRead	;
			ex_MemWrite	<=	id_MemWrite	;
			ex_ALU_Ctrl	<=	id_ALU_Ctrl	;
			ex_ALUSrcA	<=	id_ALUSrcA	;		
			ex_ALUSrcB	<=	id_ALUSrcB	;	
			ex_Branch	<=	id_Branch	;
			ex_JAL		<=	id_JAL		;
			ex_JALR		<=	id_JALR		;
			ex_Rs1		<=	id_Rs1		;
			ex_Rs2		<=	id_Rs2		;
			ex_Rd		<=	id_Rd		;
			ex_PC		<=	id_PC		;
			ex_PCImm 	<=	id_PCImm	;
			ex_PC4		<=	id_PC4		;
			ex_pred_branch_taken <= id_pred_branch_taken;

		end
	end

endmodule //id_ex
