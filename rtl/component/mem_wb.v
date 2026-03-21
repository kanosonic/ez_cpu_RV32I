//pipeline regs for MEM/WB
module mem_wb(
	input clk,
	input rstn,

	input mem_RegWrite,
	input [1:0] mem_WTR,
	input [4:0] mem_Rd,
	input [31:0] mem_PC4,
	input [31:0] mem_Data,
	input [31:0] mem_Result,
	input [31:0] mem_Imm,

	output reg wb_RegWrite,
	output reg [1:0] wb_WTR,
	output reg [4:0] wb_Rd,
	output reg [31:0] wb_PC4,
	output reg [31:0] wb_Data,
	output reg [31:0] wb_Result,
	output reg [31:0] wb_Imm
);

	always @(posedge clk) begin
		if(!rstn)begin
			wb_RegWrite <= 'd0;
			wb_WTR		<= 'd0;
			wb_Rd		<= 'd0;
			wb_PC4		<= 'd0;
			wb_Data		<= 'd0;
			wb_Result 	<= 'd0;
			wb_Imm 		<= 'd0;
		end else begin
			wb_RegWrite <= mem_RegWrite ;
			wb_WTR		<= mem_WTR		;
			wb_Rd		<= mem_Rd		;
			wb_PC4		<= mem_PC4		;
			wb_Data		<= mem_Data		;
			wb_Result 	<= mem_Result 	;
			wb_Imm 		<= mem_Imm 		;
		end
	end

endmodule
