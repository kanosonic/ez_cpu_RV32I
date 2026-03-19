//pipeline regs for IF/ID
module if_id(
	input clk,
	input rstn,
	input flush,
	input if_id_Write,

	//input [31:0] if_PC,
	input [31:0] if_PC4,
	input [31:0] if_Inst,

	//output reg [31:0] id_PC,
	output reg [31:0] id_PC4,
	output reg [31:0] id_Inst
);

	always @(posedge clk) begin
		if(!rstn || flush) begin
			//id_PC   <= 'd0;
			id_PC4  <= 'd0;
			id_Inst <= 'd0;
		end else if (if_id_Write) begin
			//id_PC   <= if_PC;
			id_PC4  <= if_PC4;
			id_Inst <= if_Inst;
		end else begin
			//id_PC   <= id_PC  ;
			id_PC4  <= id_PC4 ;
			id_Inst <= id_Inst;
		end
	end
	
endmodule //if_id
