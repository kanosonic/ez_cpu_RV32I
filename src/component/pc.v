`timescale 1ns/1ns
//for deciding the next pc value
module pc(
        input clk,
        input rstn,
        input [31:0] next_pc,
        input PCWrite,

        output reg [31:0] inst_addr	//to imem
    );
    always @(posedge clk) begin
        if(!rstn) begin
            inst_addr <= 'd0;
        end
        else begin
            
                inst_addr <= PCWrite? next_pc:inst_addr;
				
				//$display($time, "ns : inst_num = %d", inst_addr >> 2);
				
            
        end
    end
endmodule
