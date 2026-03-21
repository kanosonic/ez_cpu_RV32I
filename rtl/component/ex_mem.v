//pipeline regs for EX/MEM
module ex_mem(
	input clk,
	input rstn,

	input [2:0] ex_MemRead,
	input [1:0] ex_MemWrite,
	input ex_RegWrite,
	input [1:0] ex_WTR,

	input [31:0] ex_PC4,
	input [31:0] ex_Result,
	input [31:0] ex_Data2,
	input [31:0] ex_Imm,
	input [4:0]  ex_Rd,
	

	output reg [2:0] mem_MemRead,
	output reg [1:0]mem_MemWrite,
	output reg mem_RegWrite,
	output reg [1:0]  mem_WTR,
	output reg [31:0] mem_PC4,
	output reg [31:0] mem_Result,
	output reg [31:0] mem_Data2,
	output reg [31:0] mem_Imm,
	output reg [4:0]  mem_Rd
);

	always @(posedge clk) begin
		if(!rstn)begin
			mem_MemRead  <= 'd0;
			mem_MemWrite <= 'd0;
			mem_RegWrite <= 'd0;
			mem_WTR		 <= 'd0;
			mem_PC4		 <= 'd0;
			mem_Result	 <= 'd0;
			mem_Data2 	 <= 'd0;
			mem_Imm	 	 <= 'd0;
			mem_Rd 		 <= 'd0;

		end else begin
			mem_MemRead  <= ex_MemRead   ;
			mem_MemWrite <= ex_MemWrite  ;
			mem_RegWrite <= ex_RegWrite  ;
			mem_WTR		 <= ex_WTR		;
			mem_PC4		 <= ex_PC4		;
			mem_Result	 <= ex_Result	;
			mem_Data2 	 <= ex_Data2 	;
			mem_Imm	 	 <= ex_Imm	 	;
			mem_Rd 		 <= ex_Rd 		;

		end
	end

endmodule
