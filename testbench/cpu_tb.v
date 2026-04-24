`timescale 1ns/1ns
`include "../rtl/component/define.v"

module cpu_tb;

    reg [1023:0] hexfile_path;
    reg [1023:0] datafile_path;
    reg [1023:0] statefile_path;
    reg [1023:0] vcdfile_path;
    integer f;
    integer fd;
    integer data_fd;
    integer i;
    integer last_nonzero_idx;
    integer max_cycles;
    integer inst_num;
    integer cycle_num;
    integer branch_num;
    integer branch_taken_num;
    integer branch_pred_taken_num;
    integer branch_pred_correct;
    integer branch_pred_wrong;
    integer jal_num;
    integer jal_pred_correct;
    integer jal_pred_wrong;
    integer ctrl_pred_num;
    integer ctrl_pred_correct;
    integer ctrl_pred_wrong;
    real cpi;
    real branch_pred_accuracy;
    real branch_taken_rate;
    real branch_pred_taken_rate;
    real branch_mispredict_rate;
    real jal_pred_accuracy;
    real ctrl_pred_accuracy;
    real ctrl_mispredict_rate;
    reg [31:0] halt_pc;
    reg active_cycle;
    reg halt_pc_valid;
    reg halt_detected;
    reg simulation_done;
    reg sim_timeout_reached;
    reg useful_pipeline_active;
    reg wb_counts;
    reg branch_counts;
    reg jal_counts;
    reg has_datafile;

    function is_jal_x0;
        input [31:0] inst;
        begin
            is_jal_x0 = (inst[6:0] == 7'b1101111) && (inst[11:7] == 5'b00000);
        end
    endfunction

    function signed [31:0] jal_imm;
        input [31:0] inst;
        begin
            jal_imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
        end
    endfunction

    task finalize_simulation;
        begin
            if (!simulation_done) begin
                simulation_done = 1'b1;

                if (inst_num != 0) begin
                    cpi = cycle_num;
                    cpi = cpi / inst_num;
                end
                else begin
                    cpi = 0.0;
                end

                if (branch_num != 0) begin
                    branch_pred_accuracy = branch_pred_correct;
                    branch_pred_accuracy = 100.0 * branch_pred_accuracy / branch_num;
                    branch_taken_rate = branch_taken_num;
                    branch_taken_rate = 100.0 * branch_taken_rate / branch_num;
                    branch_pred_taken_rate = branch_pred_taken_num;
                    branch_pred_taken_rate = 100.0 * branch_pred_taken_rate / branch_num;
                    branch_mispredict_rate = branch_pred_wrong;
                    branch_mispredict_rate = 100.0 * branch_mispredict_rate / branch_num;
                end
                else begin
                    branch_pred_accuracy = 0.0;
                    branch_taken_rate = 0.0;
                    branch_pred_taken_rate = 0.0;
                    branch_mispredict_rate = 0.0;
                end

                if (jal_num != 0) begin
                    jal_pred_accuracy = jal_pred_correct;
                    jal_pred_accuracy = 100.0 * jal_pred_accuracy / jal_num;
                end
                else begin
                    jal_pred_accuracy = 0.0;
                end

                if (ctrl_pred_num != 0) begin
                    ctrl_pred_accuracy = ctrl_pred_correct;
                    ctrl_pred_accuracy = 100.0 * ctrl_pred_accuracy / ctrl_pred_num;
                    ctrl_mispredict_rate = ctrl_pred_wrong;
                    ctrl_mispredict_rate = 100.0 * ctrl_mispredict_rate / ctrl_pred_num;
                end
                else begin
                    ctrl_pred_accuracy = 0.0;
                    ctrl_mispredict_rate = 0.0;
                end

                if (sim_timeout_reached) begin
                    $display("SIM_END_REASON = MAXCYCLES_TIMEOUT");
                end
                else begin
                    $display("SIM_END_REASON = HALT_LOOP");
                end
                $display("PC = %d", u_cpu.u_pc.inst_addr);
                $display("Number of executed instruction = %d", inst_num);
                $display("Number of clock cycles = %d", cycle_num);
                $display("CPI = %4f", cpi);
                $display("BRANCH_COUNT = %d", branch_num);
                $display("BRANCH_TAKEN_COUNT = %d", branch_taken_num);
                $display("BRANCH_PRED_TAKEN_COUNT = %d", branch_pred_taken_num);
                $display("BRANCH_PRED_CORRECT = %d", branch_pred_correct);
                $display("BRANCH_PRED_WRONG = %d", branch_pred_wrong);
                $display("BRANCH_PRED_ACCURACY = %4f%%", branch_pred_accuracy);
                $display("BRANCH_TAKEN_RATE = %4f%%", branch_taken_rate);
                $display("BRANCH_PRED_TAKEN_RATE = %4f%%", branch_pred_taken_rate);
                $display("BRANCH_MISPREDICT_RATE = %4f%%", branch_mispredict_rate);
                $display("JAL_COUNT = %d", jal_num);
                $display("JAL_PRED_CORRECT = %d", jal_pred_correct);
                $display("JAL_PRED_WRONG = %d", jal_pred_wrong);
                $display("JAL_PRED_ACCURACY = %4f%%", jal_pred_accuracy);
                $display("CTRL_PRED_COUNT = %d", ctrl_pred_num);
                $display("CTRL_PRED_CORRECT = %d", ctrl_pred_correct);
                $display("CTRL_PRED_WRONG = %d", ctrl_pred_wrong);
                $display("CTRL_PRED_ACCURACY = %4f%%", ctrl_pred_accuracy);
                $display("CTRL_MISPREDICT_RATE = %4f%%", ctrl_mispredict_rate);

                f = $fopen(statefile_path, "w");
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
        end
    endtask

    initial begin
        if ($value$plusargs("HEXFILE=%s", hexfile_path)) begin
        end
        else begin
            hexfile_path = "sim/asm/build/test.dat";
        end

        if ($value$plusargs("STATEFILE=%s", statefile_path)) begin
        end
        else begin
            statefile_path = "./build/cpu_state.txt";
        end

        if ($value$plusargs("DATAFILE=%s", datafile_path)) begin
            has_datafile = 1'b1;
        end
        else begin
            datafile_path = "";
            has_datafile = 1'b0;
        end

        if ($value$plusargs("VCDFILE=%s", vcdfile_path)) begin
        end
        else begin
            vcdfile_path = "./build/cpu_tb.vcd";
        end

        if (!$value$plusargs("MAXCYCLES=%d", max_cycles)) begin
            max_cycles = 20000;
        end
    end

    initial begin
        if (!$test$plusargs("NOVCD")) begin
            $dumpfile(vcdfile_path);
            $dumpvars(0, cpu_tb);
        end
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
        repeat (max_cycles) @(negedge clk);
        sim_timeout_reached = 1'b1;
        finalize_simulation;
    end

    initial begin
        inst_rom_init(0, 4095);
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

        if (has_datafile) begin
            data_fd = $fopen(datafile_path, "r");
            if (data_fd == 0) begin
                $error("File %s NOT FOUND!", datafile_path);
                $finish;
            end
            else begin
                $display("Data file %s opened successfully", datafile_path);
                $fclose(data_fd);
            end
            @(posedge rstn);
            #1;
            $readmemh(datafile_path, u_cpu.u_data_ram.rom_Data);
        end

        $display("pc = 0x0 : %x", u_cpu.u_inst_rom.rom_data[0]);
        $display("pc = 0x4 : %x", u_cpu.u_inst_rom.rom_data[1]);
        $display("pc = 0x8 : %x", u_cpu.u_inst_rom.rom_data[2]);
        $display(" …………");

        last_nonzero_idx = -1;
        for (i = 0; i < 4096; i = i + 1) begin
            if (u_cpu.u_inst_rom.rom_data[i] != 32'b0) begin
                last_nonzero_idx = i;
            end
        end

        if (last_nonzero_idx >= 0) begin
            if (is_jal_x0(u_cpu.u_inst_rom.rom_data[last_nonzero_idx]) &&
                ($signed(jal_imm(u_cpu.u_inst_rom.rom_data[last_nonzero_idx])) == 0)) begin
                halt_pc = last_nonzero_idx << 2;
                halt_pc_valid = 1'b1;
            end
            else if ((last_nonzero_idx >= 1) &&
                     (u_cpu.u_inst_rom.rom_data[last_nonzero_idx - 1] == 32'h00000013) &&
                     is_jal_x0(u_cpu.u_inst_rom.rom_data[last_nonzero_idx]) &&
                     ($signed(jal_imm(u_cpu.u_inst_rom.rom_data[last_nonzero_idx])) == -4)) begin
                halt_pc = (last_nonzero_idx - 1) << 2;
                halt_pc_valid = 1'b1;
            end
        end

        if (halt_pc_valid) begin
            $display("Detected terminal loop at PC = %0d (0x%08h)", halt_pc, halt_pc);
        end
    end

    initial begin
        inst_num = 0;
        cycle_num = 0;
        branch_num = 0;
        branch_taken_num = 0;
        branch_pred_taken_num = 0;
        branch_pred_correct = 0;
        branch_pred_wrong = 0;
        jal_num = 0;
        jal_pred_correct = 0;
        jal_pred_wrong = 0;
        ctrl_pred_num = 0;
        ctrl_pred_correct = 0;
        ctrl_pred_wrong = 0;
        cpi = 0.0;
        branch_pred_accuracy = 0.0;
        branch_taken_rate = 0.0;
        branch_pred_taken_rate = 0.0;
        branch_mispredict_rate = 0.0;
        jal_pred_accuracy = 0.0;
        ctrl_pred_accuracy = 0.0;
        ctrl_mispredict_rate = 0.0;
        halt_pc = 32'b0;
        active_cycle = 1'b0;
        halt_pc_valid = 1'b0;
        halt_detected = 1'b0;
        simulation_done = 1'b0;
        sim_timeout_reached = 1'b0;
        useful_pipeline_active = 1'b0;
        wb_counts = 1'b0;
        branch_counts = 1'b0;
        jal_counts = 1'b0;
    end

    always @(negedge clk) begin
        #1;
        if (!simulation_done) begin
            if (halt_detected) begin
                wb_counts = (u_cpu.wb_PC4 != 32'b0) && ((u_cpu.wb_PC4 - 32'd4) < halt_pc);
                branch_counts = u_cpu.ex_Branch && (u_cpu.ex_PC < halt_pc);
                jal_counts = u_cpu.id_JAL && (u_cpu.id_PC < halt_pc);
                useful_pipeline_active =
                    ((u_cpu.id_PC4 != 32'b0) && ((u_cpu.id_PC4 - 32'd4) < halt_pc)) ||
                    ((u_cpu.ex_PC4 != 32'b0) && ((u_cpu.ex_PC4 - 32'd4) < halt_pc)) ||
                    ((u_cpu.mem_PC4 != 32'b0) && ((u_cpu.mem_PC4 - 32'd4) < halt_pc)) ||
                    ((u_cpu.wb_PC4 != 32'b0) && ((u_cpu.wb_PC4 - 32'd4) < halt_pc));
                active_cycle = useful_pipeline_active;
            end
            else begin
                wb_counts = (u_cpu.wb_PC4 != 32'b0);
                branch_counts = u_cpu.ex_Branch;
                jal_counts = u_cpu.id_JAL;
                active_cycle = (u_cpu.u_inst_rom.inst != 32'b0) ||
                               (u_cpu.id_PC4 != 32'b0) ||
                               (u_cpu.ex_PC4 != 32'b0) ||
                               (u_cpu.mem_PC4 != 32'b0) ||
                               (u_cpu.wb_PC4 != 32'b0);
            end

            if (wb_counts) begin
                inst_num = inst_num + 1;
            end

            if (active_cycle) begin
                cycle_num = cycle_num + 1;
            end

            if (branch_counts) begin
                branch_num = branch_num + 1;
                ctrl_pred_num = ctrl_pred_num + 1;
                if (u_cpu.ex_Branch_taken) begin
                    branch_taken_num = branch_taken_num + 1;
                end
                if (u_cpu.ex_pred_branch_taken) begin
                    branch_pred_taken_num = branch_pred_taken_num + 1;
                end
                if (u_cpu.ex_pred_branch_taken == u_cpu.ex_Branch_taken) begin
                    branch_pred_correct = branch_pred_correct + 1;
                    ctrl_pred_correct = ctrl_pred_correct + 1;
                end
                else begin
                    branch_pred_wrong = branch_pred_wrong + 1;
                    ctrl_pred_wrong = ctrl_pred_wrong + 1;
                end
            end

            if (jal_counts) begin
                jal_num = jal_num + 1;
                ctrl_pred_num = ctrl_pred_num + 1;
                if (u_cpu.id_pred_branch_taken) begin
                    jal_pred_correct = jal_pred_correct + 1;
                    ctrl_pred_correct = ctrl_pred_correct + 1;
                end
                else begin
                    jal_pred_wrong = jal_pred_wrong + 1;
                    ctrl_pred_wrong = ctrl_pred_wrong + 1;
                end
            end

            if (rstn && halt_pc_valid && !halt_detected && (u_cpu.u_pc.inst_addr == halt_pc)) begin
                halt_detected = 1'b1;
            end
            else if (halt_detected) begin
                if (!useful_pipeline_active) begin
                    finalize_simulation;
                end
            end
        end
    end

    task inst_rom_init;
        input integer in1;
        input integer in2;
        begin
            for (i = in1; i <= in2; i = i + 1) begin
                u_cpu.u_inst_rom.rom_data[i] = 32'b0;
            end
        end
    endtask

endmodule
