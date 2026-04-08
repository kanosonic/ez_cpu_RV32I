`timescale 1ns/1ns
module reg_file (
        input [4:0] Rs1,
        input [4:0] Rs2,
        input [4:0] Rd,
        input clk,        
		input rst_n,        
		input RegWrite,
        input [31:0] w_Data,

        output reg [31:0] r_Data1,
        output reg [31:0] r_Data2
    );
    reg [31:0] reg_Data [31:0];
    
    //write
    integer i, j, k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg_Data[i] <= 32'd0;
            end
            r_Data1 <= 32'd0;
            r_Data2 <= 32'd0;
        end
        else begin
            if (RegWrite && Rd != 'd0) begin
                reg_Data[Rd] <= w_Data;	

			end            
        end
    end


    //Read (After writen)
    always @(*) begin
        if(Rs1 == 5'd0)begin
            r_Data1 = 32'd0;
        end else begin
            if(RegWrite && (Rd != 5'd0) && (Rs1 == Rd))begin
                r_Data1 = w_Data;
            end else begin
                r_Data1 = reg_Data[Rs1];
            end
        end
    end

    always @(*) begin
        if(Rs2 == 5'd0)begin
            r_Data2 = 32'd0;
        end else begin
            if(RegWrite && (Rd != 5'd0) && (Rs2 == Rd))begin
                r_Data2 = w_Data;
            end else begin
                r_Data2 = reg_Data[Rs2];
            end
        end
    end


    initial begin
        for(i = 0; i < 32; i = i + 1) begin
            reg_Data[i] = 'd0;
        end
    end

    initial begin
        #10
        for(k = 0; k < 16; k = k + 1) begin
            #10
            $display($time, "ns");
            for(j = 0; j < 32; j = j + 1) begin
                $display("reg[%d] = %h", j, reg_Data[j]);
                
            end
        end
    end
    reg [31:0] reg_Data_r [31:0];
    //always @(posedge clk) begin
    //    for(k = 0; k < 32; k = k + 1) begin
    //        if(reg_Data[k] != reg_Data_r[k]) begin
    //            $display($time, "ns, reg[%d] = %h", k, reg_Data[k]);
    //        end
    //        reg_Data_r[k] = reg_Data[k];
    //    end
        
    //end
endmodule//reg_file
