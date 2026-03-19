`include "define.v"
module imm_gen (
    input  wire [31:0] inst,  
    output reg  [31:0] imm
);


wire [6:0] opcode = inst[6:0];

always @(*) begin
    case(opcode)
        
        `OPCODE_ALUR, `OPCODE_LOAD, `OPCODE_JALR, `OPCODE_SYSTEM, `OPCODE_ALUI: begin
            imm = {{20{inst[31]}}, inst[31:20]}; 
        end

        
        `OPCODE_STORE: begin
            imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
        end
        
        `OPCODE_BRANCH: begin
            imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
        end
        
        `OPCODE_LUI, `OPCODE_AUIPC: begin
            imm = {inst[31:12], 12'b0}; 
        end
        
        `OPCODE_JAL: begin
            imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
        end
        
        default: begin
            imm = 32'b0;
        end
    endcase
end

endmodule