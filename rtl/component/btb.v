//Branch Target Buffer
module btb #(
	parameter TAG_SIZE   = 21,	//number of bits for tag (pc[31:11])
	parameter INDEX_BITS = 9, 	//number of bits for indexing the BTB (pc[10:2])
	parameter WAY_SIZE   = 4,
	parameter SET_SIZE   = 512
)(
	input clk,
	input rstn,
	input [31:0] if_pc,
	input [31:0] ex_pc,
	input [31:0] ex_branch_target,
	input [2:0] ex_branch_type, //00 for nothing, 01 for branch, 10 for JAL
	//input ex_branch_taken,

	output reg [31:0] branch_target,
	output reg branch_hit,
	output reg [1:0] if_branch_type
);
	
	reg valid_r[SET_SIZE-1:0][WAY_SIZE-1:0];
	reg [TAG_SIZE-1:0] tag_r[SET_SIZE-1:0][WAY_SIZE-1:0];
	reg [29:0] branch_target_r[SET_SIZE-1:0][WAY_SIZE-1:0];
	reg [1:0] branch_type_r[SET_SIZE-1:0][WAY_SIZE-1:0]; //00 for nothing, 01 for branch, 10 for JAL
	// Tree-based pseudo-LRU state shared by the 4 ways in each set.
	// plru_r[2] is the root:
	//   0 -> follow plru_r[1] to choose between way0 / way1
	//   1 -> follow plru_r[0] to choose between way2 / way3
	// plru_r[1]:
	//   0 -> victim is way0
	//   1 -> victim is way1
	// plru_r[0]:
	//   0 -> victim is way2
	//   1 -> victim is way3
	//
	// Example requested by you:
	//   plru = 3'b000 -> victim way0
	//   after touching/replacing way0 -> plru = 3'b110
	//   then the next victim becomes way2
	reg [2:0] plru_r[SET_SIZE-1:0];

	wire [INDEX_BITS-1:0] if_index = if_pc[INDEX_BITS+1:2];
	wire [TAG_SIZE-1:0] if_tag = if_pc[31:INDEX_BITS+2];
	wire [INDEX_BITS-1:0] ex_index = ex_pc[INDEX_BITS+1:2];
	wire [TAG_SIZE-1:0] ex_tag = ex_pc[31:INDEX_BITS+2];

	integer set_i;
	integer way_i;
	integer lookup_way;
	integer hit_way;
	integer replace_way;

	// Decode the 3-bit tree into the current pseudo-LRU victim.
	// Example: 3'b000 selects way0, matching your requested behavior.
	function [1:0] plru_get_victim;
		input [2:0] plru_bits;
		begin
			if (plru_bits[2] == 1'b0)
				plru_get_victim = (plru_bits[1] == 1'b0) ? 2'd0 : 2'd1;
			else
				plru_get_victim = (plru_bits[0] == 1'b0) ? 2'd2 : 2'd3;
		end
	endfunction

	// Mark one way as most recently used by flipping the bits on its path.
	// For example: access way0 turns 3'b000 into 3'b110.
	function [2:0] plru_after_access;
		input [2:0] plru_bits;
		input [1:0] used_way;
		begin
			plru_after_access = plru_bits;
			case (used_way)
				2'd0: begin
					plru_after_access[2] = 1'b1;
					plru_after_access[1] = 1'b1;
				end
				2'd1: begin
					plru_after_access[2] = 1'b1;
					plru_after_access[1] = 1'b0;
				end
				2'd2: begin
					plru_after_access[2] = 1'b0;
					plru_after_access[0] = 1'b1;
				end
				2'd3: begin
					plru_after_access[2] = 1'b0;
					plru_after_access[0] = 1'b0;
				end
			endcase
		end
	endfunction

	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			for (set_i = 0; set_i < SET_SIZE; set_i = set_i + 1) begin
				plru_r[set_i] <= 3'b000;
				for (way_i = 0; way_i < WAY_SIZE; way_i = way_i + 1) begin
					valid_r[set_i][way_i] <= 1'b0;
					//tag_r[set_i][way_i] <= {TAG_SIZE{1'b0}};
					//branch_target_r[set_i][way_i] <= 30'b0;
					//branch_type_r[set_i][way_i] <= 2'b00;
				end
			end
		end else if (ex_branch_type != 3'b000) begin
			hit_way = -1;
			replace_way = -1;

			for (way_i = 0; way_i < WAY_SIZE; way_i = way_i + 1) begin
				if (valid_r[ex_index][way_i] && (tag_r[ex_index][way_i] == ex_tag))
					hit_way = way_i;
			end

			if (hit_way != -1) begin
				valid_r[ex_index][hit_way] <= 1'b1;
				tag_r[ex_index][hit_way] <= ex_tag;
				branch_target_r[ex_index][hit_way] <= ex_branch_target[31:2];
				branch_type_r[ex_index][hit_way] <= ex_branch_type[1:0];
				plru_r[ex_index] <= plru_after_access(plru_r[ex_index], hit_way[1:0]);
			end else begin
				// A no-hit branch always replaces the victim selected by the
				// pseudo-LRU tree, exactly following the 3-bit PLRU state.
				replace_way = {30'b0, plru_get_victim(plru_r[ex_index])};
				valid_r[ex_index][replace_way] <= 1'b1;
				tag_r[ex_index][replace_way] <= ex_tag;
				branch_target_r[ex_index][replace_way] <= ex_branch_target[31:2];
				branch_type_r[ex_index][replace_way] <= ex_branch_type[1:0];
				plru_r[ex_index] <= plru_after_access(plru_r[ex_index], replace_way[1:0]);
			end
		end
	end

	always @(*) begin
		branch_hit = 1'b0;
		branch_target = 32'b0;
		if_branch_type = 2'b00;

		for (lookup_way = 0; lookup_way < WAY_SIZE; lookup_way = lookup_way + 1) begin
			if (valid_r[if_index][lookup_way] &&
				(tag_r[if_index][lookup_way] == if_tag) &&
				(branch_type_r[if_index][lookup_way] != 2'b00) &&
				!branch_hit) begin
				branch_hit = 1'b1;
				branch_target = {branch_target_r[if_index][lookup_way], 2'b00};
				if_branch_type = branch_type_r[if_index][lookup_way];
			end
		end
	end


endmodule //btb
