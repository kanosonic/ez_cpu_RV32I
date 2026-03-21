`timescale 1ns/1ns
`include "../rtl/component/define.v" 
`define HEXFILE "sim/asm/build/test.dat"

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
        #15000; // 15us
        $display("PC = %d", u_cpu.u_pc.inst_addr);
        $display("Number of executed instruction = %d", inst_num);
        $display("Number of clock cycles = %d", cycle_num);
        $display("CPI = %4f", cycle_num / inst_num);
        $finish;
    end
    integer fd;
    initial begin
        inst_rom_init(0, 4096);
        //data_ram_init(0, 255);
        #10
        $write("HEXFILE = ");
        $display(`HEXFILE);

        
        fd = $fopen(`HEXFILE, "r");
        if (fd == 0) begin
            $error("File %s NOT FOUND!", `HEXFILE);
            $finish;
        end else begin
            $display("File %s opened successfully", `HEXFILE);
            $fclose(fd);
        end        

        $readmemh(`HEXFILE, u_cpu.u_inst_rom.rom_data);


        
        $display("pc = 0x0 : %x", u_cpu.u_inst_rom.rom_data[0]);
        $display("pc = 0x4 : %x", u_cpu.u_inst_rom.rom_data[1]);
        $display("pc = 0x8 : %x", u_cpu.u_inst_rom.rom_data[2]);
        $display(" …………");
    end

    real inst_num = 0, cycle_num = 0;
     always @(negedge clk) begin
         #1
         //Count the number of instructions executed by checking if MemRead or MemWrite is active, or if RegWrite is active in the write-back stage.
        if((u_cpu.mem_MemRead != 'd0) || (u_cpu.mem_MemWrite != 'd0) || u_cpu.mem_RegWrite || u_cpu.ex_Branch) begin
           inst_num = inst_num + 1;
           //$display("mem_MemRead: %d \n mem_MemWrite: %d \n mem_RegWrite: %d \n u_cpu.ex_Branch: %d \n u_cpu.id_JAL: %d \n", u_cpu.mem_MemRead, u_cpu.mem_MemWrite, u_cpu.mem_RegWrite, u_cpu.ex_Branch, u_cpu.id_JAL);
        end

            //$display("Instruction(%h) %d executed at time %t, pc = %d", u_cpu.u_inst_rom.inst, inst_num, $time, u_cpu.u_pc.inst_addr);
        
            //$display("mem_MemRead: %d \n mem_MemWrite: %d \n mem_RegWrit: %d \n", u_cpu.mem_MemRead, u_cpu.mem_MemWrite, u_cpu.mem_RegWrite);
         //Count the number of cycles by checking if the PC is not zero (indicating that the CPU has started executing instructions).
        if((u_cpu.u_pc.inst_addr != 32'b0) && (u_cpu.u_inst_rom.inst != 32'b0)) begin
            cycle_num = cycle_num + 1;
           // $display("Instruction(%h) %d executed at time %t, pc = %d", u_cpu.u_inst_rom.inst, inst_num, $time, u_cpu.u_pc.inst_addr);
        end
     end
    integer i;
    task inst_rom_init;
        input [4:0] in1, in2;
        begin
            for(i = in1; i<=in2; i = i+1) begin
                u_cpu.u_inst_rom.rom_data[i] <= 32'b0;
            end
        end
    endtask

    //task data_ram_init;
    //    input [4:0] in1, in2;
    //    begin
    //        for(i = in1; i<=in2; i = i+1) begin
    //            u_cpu.u_data_ram.dmem_reg[i] <= 32'b0;
    //        end
    //    end
    //endtask

endmodule
