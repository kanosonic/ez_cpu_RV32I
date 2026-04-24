//predicting whether the branch is taken or not
//calculating the branch target address
`ifndef DYNAMIC_PREDICTION
`define DYNAMIC_PREDICTION 1
`endif

`ifndef GHR_ON
`define GHR_ON 1
`endif

`ifndef BPU_GHR_BITS
`define BPU_GHR_BITS 8
`endif

`ifndef BPU_BHT_INDEX_BITS
`define BPU_BHT_INDEX_BITS 10
`endif

`ifndef BPU_BHT_HISTORY_BITS
`define BPU_BHT_HISTORY_BITS 2
`endif

module bpu #(
	parameter GHR_BITS = `BPU_GHR_BITS,
	parameter BHT_INDEX_BITS = `BPU_BHT_INDEX_BITS,	//> GHR_BITS when GHR is enabled
	parameter BHT_HISTORY_BITS = `BPU_BHT_HISTORY_BITS
)(
	input clk,
	input rstn,
	input [31:0] if_pc,
	input [31:0] ex_pc,
	input [31:0] ex_branch_target,
	input [2:0] ex_branch_type,
	input ex_branch_taken,
	output [31:0] branch_target,
	output pred_branch_taken
);

	localparam BHT_TABLE_SIZE = 1 << BHT_INDEX_BITS;
	localparam GHR_WIDTH = (GHR_BITS > 0) ? GHR_BITS : 1;

	wire bht_pred_branch_taken;
	wire btb_branch_hit;
	wire [1:0] btb_branch_type;
	reg [GHR_WIDTH-1:0] ghr_r;

	// gshare index:
	//   if_index = {if_pc[11:10], ghr ^ if_pc[9:2]}
	//   ex_index = {ex_pc[11:10], ghr ^ ex_pc[9:2]}
	// The BTB still keeps the raw PC for tag matching, while the BHT uses these
	// indices directly.
	
	wire [BHT_INDEX_BITS-1:0] if_index;
	wire [BHT_INDEX_BITS-1:0] ex_index;

	// Global history only tracks conditional branches.
	generate
		if (GHR_WIDTH == 1) begin : gen_ghr_shift_1
			always @(posedge clk or negedge rstn) begin
				if (!rstn)
					ghr_r <= 1'b0;
				else if (ex_branch_type == 3'b001)
					ghr_r <= ex_branch_taken;
			end
		end else begin : gen_ghr_shift_n
			always @(posedge clk or negedge rstn) begin
				if (!rstn)
					ghr_r <= {GHR_WIDTH{1'b0}};
				else if (ex_branch_type == 3'b001)
					ghr_r <= {ghr_r[GHR_WIDTH-2:0], ex_branch_taken};
			end
		end
	endgenerate

	generate
		if ((`GHR_ON != 0) && (GHR_BITS > 0)) begin : gen_ghr_on
			assign if_index = {
				if_pc[BHT_INDEX_BITS+1:GHR_BITS+2],
				ghr_r[GHR_BITS-1:0] ^ if_pc[GHR_BITS+1:2]
			};
			assign ex_index = {
				ex_pc[BHT_INDEX_BITS+1:GHR_BITS+2],
				ghr_r[GHR_BITS-1:0] ^ ex_pc[GHR_BITS+1:2]
			};
		end else begin : gen_ghr_off
			assign if_index = if_pc[BHT_INDEX_BITS+1:2];
			assign ex_index = ex_pc[BHT_INDEX_BITS+1:2];
		end
	endgenerate

	bht #(
		.HISTORY_BITS(BHT_HISTORY_BITS),
		.TABLE_SIZE(BHT_TABLE_SIZE),
		.INDEX_BITS(BHT_INDEX_BITS)
	) u_bht(
		.clk(clk),
		.rstn(rstn),
		.ex_branch_valid(ex_branch_type == 3'b001),
		.ex_branch_taken(ex_branch_taken),
		.if_index(if_index),
		.ex_index(ex_index),
		.if_pred_branch_taken(bht_pred_branch_taken)
	);

	btb u_btb(
		.clk(clk),
		.rstn(rstn),
		.if_pc(if_pc),
		.ex_pc(ex_pc),
		.ex_branch_target(ex_branch_target),
		.ex_branch_type(ex_branch_type),
		.branch_target(branch_target),
		.branch_hit(btb_branch_hit),
		.if_branch_type(btb_branch_type)
	);

	// JAL is always taken, so a BTB hit is enough to predict it.
	// Conditional branches still use the BHT direction prediction.
	generate
		if (`DYNAMIC_PREDICTION != 0) begin : gen_dynamic_prediction
			assign pred_branch_taken =
				btb_branch_hit &&
				((btb_branch_type == 2'b10) ||
				 ((btb_branch_type == 2'b01) && bht_pred_branch_taken));
		end else begin : gen_static_prediction
			assign pred_branch_taken = 1'b0;
		end
	endgenerate
endmodule //bpu
