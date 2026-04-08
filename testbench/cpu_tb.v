`timescale 1ns/1ns
`include "../rtl/component/define.v"

module cpu_tb;

    reg [1023:0] hexfile_path;
    integer f;
    integer fd;
    integer i;
    integer inst_num;
    integer cycle_num;
    real cpi;

    initial begin
        if ($value$plusargs("HEXFILE=%s", hexfile_path)) begin
        end
        else begin
            hexfile_path = "sim/asm/build/test.dat";
        end
    end

    initial begin
        $dumpfile("./build/cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end

    reg clk;
    reg rstn;

    parameter clk_freq = 100000000;

    initial begin
        clk = 1'b0;
        rstn = 1'b0;
        #20 rstn = 1'b1;
    end

    always #5 clk = !clk;

    cpu u_cpu(
        .clk(clk),
        .rstn(rstn)
    );

    initial begin
        #15000;
        if (inst_num != 0) begin
            cpi = cycle_num;
            cpi = cpi / inst_num;
        end
        else begin
            cpi = 0.0;
        end

        $display("PC = %d", u_cpu.u_pc.inst_addr);
        $display("Number of executed instruction = %d", inst_num);
        $display("Number of clock cycles = %d", cycle_num);
        $display("CPI = %4f", cpi);

        f = $fopen("./build/cpu_state.txt", "w");
        $fwrite(f, "# Registers\n");
        for (i = 0; i < 32; i = i + 1) begin
            $fwrite(f, "x%0d: 0x%08h\n", i, u_cpu.u_reg_file.reg_Data[i]);
        end
        $fwrite(f, "\n# Data Memory (128 bytes from addr 0)\n");
        for (i = 0; i < 128; i = i + 1) begin
            $fwrite(f, "mem[%0d]: 0x%02h\n", i, u_cpu.u_data_ram.rom_Data[i]);
        end
        $fclose(f);

        $finish;
    end

    initial begin
        inst_rom_init(0, 4096);
        #10;
        $write("HEXFILE = %s\n", hexfile_path);

        fd = $fopen(hexfile_path, "r");
        if (fd == 0) begin
            $error("File %s NOT FOUND!", hexfile_path);
            $finish;
        end
        else begin
            $display("File %s opened successfully", hexfile_path);
            $fclose(fd);
        end

        $readmemh(hexfile_path, u_cpu.u_inst_rom.rom_data);

        $display("pc = 0x0 : %x", u_cpu.u_inst_rom.rom_data[0]);
        $display("pc = 0x4 : %x", u_cpu.u_inst_rom.rom_data[1]);
        $display("pc = 0x8 : %x", u_cpu.u_inst_rom.rom_data[2]);
        $display(" …………");
    end

    initial begin
        inst_num = 0;
        cycle_num = 0;
        cpi = 0.0;
    end

    always @(negedge clk) begin
        #1;
        if (u_cpu.wb_PC4 != 32'b0) begin
            inst_num = inst_num + 1;
        end

        if ((u_cpu.u_inst_rom.inst != 32'b0) ||
            (u_cpu.id_PC4 != 32'b0) ||
            (u_cpu.ex_PC4 != 32'b0) ||
            (u_cpu.mem_PC4 != 32'b0) ||
            (u_cpu.wb_PC4 != 32'b0)) begin
            cycle_num = cycle_num + 1;
        end
    end

    task inst_rom_init;
        input integer in1;
        input integer in2;
        begin
            for (i = in1; i <= in2; i = i + 1) begin
                u_cpu.u_inst_rom.rom_data[i] <= 32'b0;
            end
        end
    endtask

endmodule
