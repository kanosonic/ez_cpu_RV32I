module hazard_detector(

	input ex_JALR,	
	input ex_pred_fail,	
	input ex_MemRead,
	input id_JAL,
	input id_pred_branch_taken,
	input [4:0] id_Rs1,
	input [4:0] id_Rs2,
	input [4:0] ex_Rd,
		

	output reg PCWrite,	//0 for stalling

	output reg if_id_Write,	//0 for stalling
	output reg if_id_Flush,	//1 for flushing

	output reg id_ex_Flush	//1 for flushing
);

	wire load_use_hazard;
	assign load_use_hazard = ex_MemRead && ((ex_Rd == id_Rs1) || (ex_Rd == id_Rs2));

	always @(*) begin
		if (ex_JALR || ex_pred_fail) begin
			PCWrite     = 1'b1;
			if_id_Write = 1'b0;
			if_id_Flush = 1'b1;
			id_ex_Flush = 1'b1;
		end else if (load_use_hazard) begin
			PCWrite     = 1'b0;
			if_id_Write = 1'b0;
			if_id_Flush = 1'b0;
			id_ex_Flush = 1'b1;
		end else if (id_JAL && !id_pred_branch_taken) begin
			PCWrite     = 1'b1;
			if_id_Write = 1'b0;
			if_id_Flush = 1'b1;
			id_ex_Flush = 1'b0;
		end else begin
			PCWrite     = 1'b1;
			if_id_Write = 1'b1;
			if_id_Flush = 1'b0;
			id_ex_Flush = 1'b0;
		end
	end
endmodule
