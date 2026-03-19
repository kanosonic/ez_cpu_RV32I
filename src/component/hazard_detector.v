module hazard_detector(

	input ex_JALR,	
	input ex_Branch_taken,	
	input [4:0] id_Rs1,
	input [4:0] id_Rs2,
	input [4:0] ex_Rd,
	input ex_MemRead,	

	output reg PCWrite,	//0 for stalling

	output reg if_id_Write,	//0 for stalling
	output reg if_id_Flush,	//1 for flushing

	output reg id_ex_Flush	//1 for flushing
);

	always @(*) begin
		case ({ex_JALR, ex_Branch_taken, ex_MemRead})
		
			// for JALR (penalty = 2)
			// 1.change pc to destination	
			// 2.flush if_id and id_ex
			3'b100: begin
				PCWrite     = 1'b1;
				if_id_Write = 1'b0;
				if_id_Flush = 1'b1;
				id_ex_Flush = 1'b1;
			end

			// for Branch (penalty = 2)
			// 1.change pc to destination	
			// 2.flush if_id and id_ex
			3'b010: begin
				PCWrite     = 1'b1;
				if_id_Write = 1'b0;
				if_id_Flush = 1'b1;
				id_ex_Flush = 1'b1;
			end

			// for use-after-load (penalty = 1)
			// 1.stall pc and if_id
			// 2.flush id_ex
			3'b001: begin
				if((ex_Rd == id_Rs1) || (ex_Rd == id_Rs2))begin
				PCWrite     = 1'b0;
				if_id_Write = 1'b0;
				if_id_Flush = 1'b0;
				id_ex_Flush = 1'b1;
				end else begin
					PCWrite     = 1'b1;
					if_id_Write = 1'b1;
					if_id_Flush = 1'b0;
					id_ex_Flush = 1'b0;					
				end
			end
			
			default: begin
				PCWrite     = 1'b1;
				if_id_Write = 1'b1;
				if_id_Flush = 1'b0;
				id_ex_Flush = 1'b0;
			end
		endcase
	end
endmodule
