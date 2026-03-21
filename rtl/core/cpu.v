`include "define.v"

module cpu(
        input clk,
        input rstn
    );

    // ---------- IF stage ----------
    wire [31:0] pc;
    wire [31:0] pc4;
    wire [31:0] inst;

    wire PCWrite;
    wire if_id_Write;
    wire if_id_Flush;
    wire id_ex_Flush;

    wire [31:0] next_pc;

    // ---------- ID stage ----------
    wire [31:0] id_PC;
    wire [31:0] id_PC4;
    wire [31:0] id_Inst;

    wire [31:0] id_Imm;
    wire [31:0] id_rdata1;
    wire [31:0] id_rdata2;

    wire id_RegWrite;
    wire [1:0] id_WTR;
    wire [2:0] id_MemRead;
    wire [1:0] id_MemWrite;
    wire [1:0] id_ALU_Op;
    wire [3:0] id_ALU_Ctrl;
    wire id_ALUSrcA;
    wire id_ALUSrcB;
    wire id_Branch;
    wire id_JALR;
    wire id_JAL;

    wire [4:0] id_Rs1 = id_Inst[19:15];
    wire [4:0] id_Rs2 = id_Inst[24:20];
    wire [4:0] id_Rd  = id_Inst[11:7];

    wire [31:0] id_PCImm;

    // ---------- EX stage ----------
    wire [31:0] ex_Imm;
    wire [31:0] ex_Data1;
    wire [31:0] ex_Data2;

    wire ex_RegWrite;
    wire [1:0] ex_WTR;
    wire [2:0] ex_MemRead;
    wire [1:0] ex_MemWrite;
    wire [3:0] ex_ALU_Ctrl;
    wire ex_ALUSrcA;
    wire ex_ALUSrcB;
    wire ex_Branch;
    wire ex_JALR;

    wire [4:0] ex_Rs1;
    wire [4:0] ex_Rs2;
    wire [4:0] ex_Rd;

    wire [31:0] ex_PC;
    wire [31:0] ex_PC4;

    wire [31:0] ex_PCImm;
    wire [31:0] ex_ALU_Result;
    wire [31:0] ex_Rs1Imm;

    wire ex_Branch_taken;
	wire ex_Branch_cond;

    // Forwarding
    wire [1:0] forwardA;
    wire [1:0] forwardB;

    wire [31:0] forwardA_data;
    wire [31:0] forwardB_data;

    // ---------- EX/MEM stage ----------
    wire [2:0] mem_MemRead;
    wire [1:0] mem_MemWrite;
    wire mem_RegWrite;
    wire [1:0] mem_WTR;
    wire [31:0] mem_PC4;
    wire [31:0] mem_Result;
    wire [31:0] mem_Data2;
    wire [31:0] mem_Imm;
    wire [4:0]  mem_Rd;

    // ---------- MEM stage ----------
    wire [31:0] mem_rdata;

    // ---------- MEM/WB stage ----------
    wire wb_RegWrite;
    wire [1:0] wb_WTR;
    wire [4:0] wb_Rd;
    wire [31:0] wb_PC4;
    wire [31:0] wb_Data;
    wire [31:0] wb_Result;
    wire [31:0] wb_Imm;

    wire [31:0] wb_wdata;

    // ---------- IF stage logic ----------
    adder32 u_adder_pc4(
                .A(pc),
                .B(32'd4),
                .Result(pc4)
            );

    next_pc u_next_pc(
                .id_JAL(id_JAL),
                .ex_Branch_taken(ex_Branch_taken),
                .ex_JALR(ex_JALR),
                .if_PC4(pc4),
                .id_PCImm(id_PCImm),
                .ex_PCImm(ex_PCImm),
                .ex_Rs1Imm(ex_Rs1Imm),
                .next_PC(next_pc)
            );

    pc u_pc(
           .clk(clk),
           .rstn(rstn),
           .next_pc(next_pc),
           .PCWrite(PCWrite),
           .inst_addr(pc)
       );

    inst_rom u_inst_rom(
                 .addr(pc),
                 .inst(inst)
             );

    if_id u_if_id(
              .clk(clk),
              .rstn(rstn),
              .flush(if_id_Flush),
              .if_id_Write(if_id_Write),
              .if_PC(pc),
              .if_PC4(pc4),
              .if_Inst(inst),
              .id_PC(id_PC),
              .id_PC4(id_PC4),
              .id_Inst(id_Inst)
          );

    // ---------- ID stage logic ----------
    controller u_controller(
                   .id_Inst(id_Inst),
                   .id_RegWrite(id_RegWrite),
                   .id_WTR(id_WTR),
                   .id_MemRead(id_MemRead),
                   .id_MemWrite(id_MemWrite),
                   .id_ALU_Op(id_ALU_Op),
                   .id_ALUSrcA(id_ALUSrcA),
                   .id_ALUSrcB(id_ALUSrcB),
                   .id_Branch(id_Branch),
                   .id_JALR(id_JALR),
                   .id_JAL(id_JAL)
               );

    ALU_Ctrl u_alu_ctrl(
                 .ALU_Op(id_ALU_Op),
                 .funct7(id_Inst[31:25]),
                 .funct3(id_Inst[14:12]),
                 .ALU_Ctrl(id_ALU_Ctrl)
             );

    imm_gen u_imm_gen(
                .inst(id_Inst),
                .imm(id_Imm)
            );

    adder32 u_adder_id_pcimm(
                .A(id_PC),
                .B(id_Imm),
                .Result(id_PCImm)
            );

    reg_file u_reg_file(
                 .Rs1(id_Rs1),
                 .Rs2(id_Rs2),
                 .Rd(wb_Rd),
                 .clk(clk),
                 .rst_n(rstn),
                 .RegWrite(wb_RegWrite),
                 .w_Data(wb_wdata),
                 .r_Data1(id_rdata1),
                 .r_Data2(id_rdata2)
             );

    // ---------- ID/EX pipeline register ----------
    id_ex u_id_ex(
              .clk(clk),
              .rstn(rstn),
              .flush(id_ex_Flush),

              .id_Imm(id_Imm),
              .id_Data1(id_rdata1),
              .id_Data2(id_rdata2),

              .id_RegWrite(id_RegWrite),
              .id_WTR(id_WTR),
              .id_MemRead(id_MemRead),
              .id_MemWrite(id_MemWrite),
              .id_ALU_Ctrl(id_ALU_Ctrl),
              .id_ALUSrcA(id_ALUSrcA),
              .id_ALUSrcB(id_ALUSrcB),
              .id_Branch(id_Branch),
              .id_JALR(id_JALR),

              .id_Rs1(id_Rs1),
              .id_Rs2(id_Rs2),
              .id_Rd(id_Rd),
              .id_PC(id_PC),
              .id_PC4(id_PC4),
			  .id_PCImm(id_PCImm),

              .ex_Imm(ex_Imm),
              .ex_Data1(ex_Data1),
              .ex_Data2(ex_Data2),
              .ex_RegWrite(ex_RegWrite),
              .ex_WTR(ex_WTR),
              .ex_MemRead(ex_MemRead),
              .ex_MemWrite(ex_MemWrite),
              .ex_ALU_Ctrl(ex_ALU_Ctrl),
              .ex_ALUSrcA(ex_ALUSrcA),
              .ex_ALUSrcB(ex_ALUSrcB),
              .ex_Branch(ex_Branch),
              .ex_JALR(ex_JALR),

              .ex_Rs1(ex_Rs1),
              .ex_Rs2(ex_Rs2),
              .ex_Rd(ex_Rd),
              .ex_PC(ex_PC),
			  .ex_PCImm(ex_PCImm),
              .ex_PC4(ex_PC4)
          );

    // ---------- EX stage logic ----------
    wire ex_MemRead_flag = (ex_MemRead != `MEMREAD_NOP);

    forward_unit u_forward_unit(
                     .ex_Rs1(ex_Rs1),
                     .ex_Rs2(ex_Rs2),
                     .mem_Rd(mem_Rd),
                     .wb_Rd(wb_Rd),
                     .mem_RegWrite(mem_RegWrite),
                     .wb_RegWrite(wb_RegWrite),
                     .ForwardA(forwardA),
                     .ForwardB(forwardB)
                 );

    assign forwardA_data = (forwardA == `FORWARD_A_EX) ? mem_Result :
           (forwardA == `FORWARD_A_MEM) ? wb_wdata :
           ex_Data1;

    assign forwardB_data = (forwardB == `FORWARD_B_EX) ? mem_Result :
           (forwardB == `FORWARD_B_MEM) ? wb_wdata :
           ex_Data2;

	assign ex_Branch_taken = ex_Branch && ex_Branch_cond;

    wire [31:0] alu_in1 = ex_ALUSrcA ? ex_PC : forwardA_data;
    wire [31:0] alu_in2 = ex_ALUSrcB ? ex_Imm : forwardB_data;

    alu u_alu(
            .A(alu_in1),
            .B(alu_in2),
            .ALU_Ctrl(ex_ALU_Ctrl),
            .Result(ex_ALU_Result),
            .Branch_cond(ex_Branch_cond)
        );

    //// Branch / JAL target = PC + imm
    //adder32 u_adder_ex_pcimm(
    //            .A(ex_PC),
    //            .B(ex_Imm),
    //            .Result(ex_PCImm)
    //        );

    // Use ALU result for JALR target computation
    assign ex_Rs1Imm = ex_ALU_Result & ~32'b1; // for JALR

    // EX/MEM pipeline register
    ex_mem u_ex_mem(
               .clk(clk),
               .rstn(rstn),
               .ex_MemRead(ex_MemRead),
               .ex_MemWrite(ex_MemWrite),
               .ex_RegWrite(ex_RegWrite),
               .ex_WTR(ex_WTR),
               .ex_PC4(ex_PC4),
               .ex_Result(ex_ALU_Result),
               .ex_Data2(forwardB_data),
               .ex_Imm(ex_Imm),
               .ex_Rd(ex_Rd),

               .mem_MemRead(mem_MemRead),
               .mem_MemWrite(mem_MemWrite),
               .mem_RegWrite(mem_RegWrite),
               .mem_WTR(mem_WTR),
               .mem_PC4(mem_PC4),
               .mem_Result(mem_Result),
               .mem_Data2(mem_Data2),
               .mem_Imm(mem_Imm),
               .mem_Rd(mem_Rd)
           );

    // ---------- MEM stage logic ----------
    data_ram u_data_ram(
                 .clk(clk),
                 .rstn(rstn),
                 .MemRead(mem_MemRead),
                 .MemWrite(mem_MemWrite),
                 .Addr(mem_Result),
                 .w_Data(mem_Data2),
                 .r_Data(mem_rdata)
             );

    // ---------- MEM/WB stage ----------
    mem_wb u_mem_wb(
               .clk(clk),
               .rstn(rstn),
               .mem_RegWrite(mem_RegWrite),
               .mem_WTR(mem_WTR),
               .mem_Rd(mem_Rd),
               .mem_PC4(mem_PC4),
               .mem_Data(mem_rdata),
               .mem_Result(mem_Result),
               .mem_Imm(mem_Imm),

               .wb_RegWrite(wb_RegWrite),
               .wb_WTR(wb_WTR),
               .wb_Rd(wb_Rd),
               .wb_PC4(wb_PC4),
               .wb_Data(wb_Data),
               .wb_Result(wb_Result),
               .wb_Imm(wb_Imm)
           );

    // Writeback data selection
    assign wb_wdata = (wb_WTR == `WTR_MEM) ? wb_Data :
                      (wb_WTR == `WTR_ALU) ? wb_Result :
                      (wb_WTR == `WTR_PC4) ? wb_PC4 :
                      (wb_WTR == `WTR_IMM) ? wb_Imm :
                      32'b0;

    // Hazard detection
    hazard_detector u_hazard_detector(
                        .ex_JALR(ex_JALR),
                        .ex_Branch_taken(ex_Branch_taken),
                        .ex_MemRead(ex_MemRead_flag),
                        .id_JAL(id_JAL),
                        .id_Rs1(id_Rs1),
                        .id_Rs2(id_Rs2),
                        .ex_Rd(ex_Rd),
                        

                        .PCWrite(PCWrite),
                        .if_id_Write(if_id_Write),
                        .if_id_Flush(if_id_Flush),
                        .id_ex_Flush(id_ex_Flush)
                    );

endmodule
