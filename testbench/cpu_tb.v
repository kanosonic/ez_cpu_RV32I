`timescale 1ns/1ns

module cpu_tb;
    initial begin
        $dumpfile("./build/cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end

    reg clk;
    reg rstn;

    parameter clk_freq = 100000000; // 100MHz

    initial begin
        clk = 1'b0;
        rstn = 1'b0;
        #20 rstn = 1'b1;
    end

    always #5 clk = !clk; // 10ns period, 100MHz

    // Instantiate the CPU
    cpu u_cpu(
            .clk(clk),
            .rstn(rstn)
        );

    initial begin
        // Run simulation for a certain time
        #1000; // 1us
        $finish;
    end

endmodule
