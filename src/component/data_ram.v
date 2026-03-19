`include "define.v"
module data_ram #(
        parameter BIT_WIDTH = 32,
        parameter ADDR_WIDTH = 32
    ) (
        input clk,
        input rstn,
        input [2:0] MemRead,
        input [1:0] MemWrite,
        input [ADDR_WIDTH - 1:0] Addr,
        input [BIT_WIDTH - 1:0] w_Data,

        output reg [BIT_WIDTH - 1:0] r_Data

    );
    reg [7:0] rom_Data [1023:0];	//1KB

    //Write
    integer i;
    always @(posedge clk) begin
        if(!rstn) begin
            for(i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
                rom_Data[i] <= 'd0;
            end
        end
        else begin
            case (MemWrite)

                `MEMWRITE_SW: begin
                    rom_Data[Addr + 3] <= w_Data[31: 24];
                    rom_Data[Addr + 2] <= w_Data[23: 16];
                    rom_Data[Addr + 1] <= w_Data[15: 8] ;
                    rom_Data[Addr] 	   <= w_Data[7: 0]  ;
                end

                `MEMWRITE_SH: begin
                    rom_Data[Addr + 1] <= w_Data[15: 8];
                    rom_Data[Addr]	   <= w_Data[7: 0];
                end

                `MEMWRITE_SB: begin
                    rom_Data[Addr] <= w_Data[7: 0];
                end
                default: begin

                end
            endcase
        end

    end

    //Read
    always @(*) begin
        case (MemRead)

            `MEMREAD_LW: begin
                r_Data = {rom_Data[Addr + 3], rom_Data[Addr + 2], rom_Data[Addr + 1], rom_Data[Addr]};
            end

            `MEMREAD_LH: begin
                r_Data = {{16{rom_Data[Addr + 1][7]}}, rom_Data[Addr + 1], rom_Data[Addr]};
            end

            `MEMREAD_LHU: begin
                r_Data = {16'b0, rom_Data[Addr + 1], rom_Data[Addr]};
            end

            `MEMREAD_LB: begin
                r_Data = {{24{rom_Data[Addr][7]}}, rom_Data[Addr]};
            end

            `MEMREAD_LBU: begin
                r_Data = {24'b0, rom_Data[Addr]};
            end

            default: begin
                r_Data = 32'b0;
            end

        endcase
    end

    always @(posedge clk) begin

    end

endmodule
