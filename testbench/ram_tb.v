`timescale 1ns/1ns

module ram_tb;
    initial begin
        $dumpfile("ram_tb.vcd");
        $dumpvars(0, ram_tb);
    end
    reg clk;
    reg rstn    ;



    parameter    clk_freq    = 100000000 ; //100MHz
    parameter   ADDR_WIDTH = 10;
    parameter   BIT_WIDTH = 32;


    initial begin
        clk           = 1'b0 ;
        rstn          = 1'b0 ;
        #20
         rstn          = 1'b1 ;
    end
    always #5 clk = !clk;

    // output declaration of module ram
    wire [31:0] r_data;
    reg MemRead;
    reg MemWrite;
    reg [31:0] addr;
    reg [31:0] w_data;
    data_ram #(
            .BIT_WIDTH  	(BIT_WIDTH  ),
            .ADDR_WIDTH 	(ADDR_WIDTH  ))
        u_ram(
            .clk      	(clk       ),
            .rstn     	(rstn      ),
            .MemRead  	(MemRead   ),
            .MemWrite 	(MemWrite  ),
            .addr     	(addr      ),
            .w_data   	(w_data    ),
            .r_data   	(r_data    )
        );

    integer i =0;
    initial begin
        #200
         MemRead = 0;
        MemWrite = 1;
        addr = 'd3;
        w_data = 'h1234ABCD;
        #20
         MemRead = 1;
        MemWrite = 0;
        addr = 'd3;




        #200
         MemRead = 0;
        MemWrite = 1;
        addr = 'd5;
        w_data = 'h12345678;
        #20
         MemRead = 1;
        MemWrite = 0;
        addr = 'd5;

        repeat(100) begin
            #200
             MemRead = 0;
            MemWrite = 1;
            addr = $random % (1 << ADDR_WIDTH - 1);
            w_data = $random % (1 << BIT_WIDTH - 1);
            #20
             MemRead = 1;
            MemWrite = 0;

            $display($time, "ns: addr = %d, w_data = %d, r_data = %d", addr, w_data, r_data);


        end

        $display("Passed!");
    end

    always begin
        #100;
        if ($time >= 500000)
            $finish ;
    end

endmodule
