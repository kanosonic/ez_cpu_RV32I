module next_pc(
	input clk,
	input rstn,
	input id_JAL,
	input id_pred_branch_taken,
	input ex_Branch,
	input ex_JAL,
	input ex_Branch_taken,
	input ex_pred_fail,
	input ex_JALR,
	
	input [31:0] if_PC,
	input [31:0] if_PC4,
	input [31:0] id_PCImm,
	input [31:0] ex_PC,
	input [31:0] ex_PCImm,
	input [31:0] ex_PC4,
	input [31:0] ex_Rs1Imm,

	output reg [31:0] next_PC,
	output if_pred_branch_taken
);
	wire [31:0] if_branch_target;
	wire [2:0] ex_branch_type;

	assign ex_branch_type = ex_Branch ? 3'b001 :
	                        ex_JAL    ? 3'b010 :
	                        3'b000;

	bpu u_bpu(
		.clk(clk),
		.rstn(rstn),
		.if_pc(if_PC),
		.ex_pc(ex_PC),
		.ex_branch_target(ex_PCImm),
		.ex_branch_type(ex_branch_type),
		.ex_branch_taken(ex_Branch_taken),
		.branch_target(if_branch_target),
		.pred_branch_taken(if_pred_branch_taken)
	);

	always @(*) begin
		if (ex_JALR)
			next_PC = ex_Rs1Imm;
		else if (ex_pred_fail)
			next_PC = ex_Branch_taken ? ex_PCImm : ex_PC4;
		else if (id_JAL && !id_pred_branch_taken)
			next_PC = id_PCImm;
		else if (if_pred_branch_taken)
			next_PC = if_branch_target;
		else
			next_PC = if_PC4;
	end
	
endmodule //next_pc
