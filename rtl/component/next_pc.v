module next_pc(
	input id_JAL,
	input ex_Branch_taken,
	input ex_JALR,
	
	input [31:0] if_PC4,
	input [31:0] id_PCImm,
	input [31:0] ex_PCImm,
	input [31:0] ex_Rs1Imm,

	output reg [31:0] next_PC
);
	always @(*) begin
		case ({id_JAL, ex_Branch_taken, ex_JALR})
			3'b000: next_PC = if_PC4;
			3'b100: next_PC = id_PCImm;
			3'b010: next_PC = ex_PCImm;
			3'b001: next_PC = ex_Rs1Imm;
			default: begin
					next_PC = if_PC4;	//avoid making a latch
					if($time > 5) $display($time, "ns: Can't get next PC!");				
			end
		endcase
	end
	
endmodule //next_pc
