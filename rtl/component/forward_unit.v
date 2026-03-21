//for deciding which to forward
module forward_unit(
	input [4:0] ex_Rs1,
	input [4:0] ex_Rs2,
	input [4:0] mem_Rd,
	input [4:0] wb_Rd,
	input mem_RegWrite,
	input wb_RegWrite,

	output reg [1:0] ForwardA,
	output reg [1:0] ForwardB
);

	always @(*) begin
		
		//priotity: EX > MEM > no hazard
		if(mem_RegWrite && (mem_Rd != 0) && (mem_Rd == ex_Rs1))begin
			ForwardA = 2'b10;	//forward from EX stage
		end else if(wb_RegWrite && (wb_Rd != 0) && (wb_Rd == ex_Rs1))begin
			ForwardA = 2'b01;	//forward from MEM stage
		end else begin
			ForwardA = 2'b00;	//no hazard
		end

		if(mem_RegWrite && (mem_Rd != 0) && (mem_Rd == ex_Rs2))begin
			ForwardB = 2'b10;
		end else if(wb_RegWrite && (wb_Rd != 0) && (wb_Rd == ex_Rs2))begin
			ForwardB = 2'b01;
		end else begin
			ForwardB = 2'b00;
		end
	end


endmodule
