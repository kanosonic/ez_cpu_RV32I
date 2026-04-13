//Branch History Table (BHT) for direction prediction
module bht #(
	parameter HISTORY_BITS = 2,	//number of bits for branch history
	parameter TABLE_SIZE = 1024,	//size of the BHT
	parameter INDEX_BITS = 10	//number of bits for indexing the BHT (log2(TABLE_SIZE))
)(
	input clk,
	input rstn,
	input ex_branch_valid,
	input ex_branch_taken,
	input [INDEX_BITS-1:0] if_index,
	input [INDEX_BITS-1:0] ex_index,
	output reg if_pred_branch_taken
);

	reg [HISTORY_BITS-1:0] branch_counter_r[TABLE_SIZE-1:0];

	integer i;

	// 2-bit saturating counter:
	//   00: strongly not taken
	//   01: weakly not taken
	//   10: weakly taken
	//   11: strongly taken
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			for (i = 0; i < TABLE_SIZE; i = i + 1) begin
				branch_counter_r[i] <= {HISTORY_BITS{1'b0}};
			end
		end else if (ex_branch_valid) begin
			if (ex_branch_taken) begin
				if (branch_counter_r[ex_index] != {HISTORY_BITS{1'b1}})
					branch_counter_r[ex_index] <= branch_counter_r[ex_index] + 1'b1;
			end else begin
				if (branch_counter_r[ex_index] != {HISTORY_BITS{1'b0}})
					branch_counter_r[ex_index] <= branch_counter_r[ex_index] - 1'b1;
			end
		end
	end

	// Asynchronous prediction: use the counter MSB as the taken/not-taken bit.
	always @(*) begin
		if_pred_branch_taken = branch_counter_r[if_index][HISTORY_BITS-1];
	end
	

endmodule //bht
