//for storing instructions, read-only
module inst_rom(
	input [31:0] addr,
	output reg [31:0] inst
);

	reg [31:0] rom_data [0:4096];
	//integer i;
	//initial begin
	//	for(i = 0; i < 256; i = i + 1) begin
	//		rom_data[i] = 'd0;
	//	end

	//	rom_data[0 ] = 32'h20000e13;  // addi  x28, x0, 0x200           | x28=0x00000200
	//	rom_data[1 ] = 32'h00000097;  // auipc x1, 0                    | x1=0x00000004
	//	rom_data[2 ] = 32'h001e2023;  // sw    x1, 0(x28)               | mem[0x200]=0x00000004(x1)
	//	rom_data[3 ] = 32'h0040016f;  // jal   x2, jal_target           | x2=0x00000010(ret), jump=0x0010

	//	// jal_target (0x0010):
	//	rom_data[4 ] = 32'heef00193;  // addi  x3, x0, 0xbeef           | x3=0xffffbeef (sign-extended from 0xeef)
	//	rom_data[5 ] = 32'h002e2223;  // sw    x2, 4(x28)               | mem[0x204]=0x00000010(x2)
	//	rom_data[6 ] = 32'h003e2423;  // sw    x3, 8(x28)               | mem[0x208]=0xffffbeef(x3)
	//	rom_data[7 ] = 32'h00000217;  // auipc x4, 0                    | x4=0x0000001c
	//	rom_data[8 ] = 32'h01020213;  // addi  x4, x4, 16               | x4=0x0000002c
	//	rom_data[9 ] = 32'h000202e7;  // jalr  x5, x4, 0               | x5=0x00000028(ret), jump=0x0000002c

	//	// jalr_target (0x0028):
	//	rom_data[10] = 32'hace00313;  // addi  x6, x0, 0xface           | x6=0xffffface (sign-extended from 0xace)
	//	rom_data[11] = 32'h005e2623;  // sw    x5, 12(x28)              | mem[0x20c]=0x00000028(x5)
	//	rom_data[12] = 32'h006e2823;  // sw    x6, 16(x28)              | mem[0x210]=0xffffface(x6)
	//	rom_data[13] = 32'h00000263;  // beq   x0, x0, branch_target   | branch_taken, jump=0x0038

	//	// branch_target (0x0038):
	//	rom_data[14] = 32'h00d00393;  // addi  x7, x0, 0x600d           | x7=0x0000600d (0x600d & 0xfff = 0x00d, sign bit=0)
	//	rom_data[15] = 32'h007e2a23;  // sw    x7, 20(x28)              | mem[0x214]=0x0000600d(x7)
	//	rom_data[16] = 32'h00a00413;  // addi  x8, x0, 10               | x8=0x0000000a
	//	rom_data[17] = 32'h00a00493;  // addi  x9, x0, 10               | x9=0x0000000a
	//	rom_data[18] = 32'h00940263;  // beq   x8, x9, beq_eq           | branch_taken, jump=0x004c

	//	// beq_eq (0x004c):
	//	rom_data[19] = 32'h00200513;  // addi  x10, x0, 2               | x10=0x00000002
	//	rom_data[20] = 32'h00ae2c23;  // sw    x10, 24(x28)             | mem[0x218]=0x00000002(x10)
	//	rom_data[21] = 32'h01400593;  // addi  x11, x0, 20              | x11=0x00000014
	//	rom_data[22] = 32'h00b41263;  // bne   x8, x11, bne_ne          | branch_taken, jump=0x005c

	//	// bne_ne (0x005c):
	//	rom_data[23] = 32'h00400613;  // addi  x12, x0, 4               | x12=0x00000004
	//	rom_data[24] = 32'h00ce2e23;  // sw    x12, 28(x28)             | mem[0x21c]=0x00000004(x12)
	//	rom_data[25] = 32'h00500693;  // addi  x13, x0, 5               | x13=0x00000005
	//	rom_data[26] = 32'h00600713;  // addi  x14, x0, 6               | x14=0x00000006
	//	rom_data[27] = 32'h00e687b3;  // add   x15, x13, x14            | x15=0x0000000b
	//	rom_data[28] = 32'h00178813;  // addi  x16, x15, 1              | x16=0x0000000c
	//	rom_data[29] = 32'h030e2023;  // sw    x16, 32(x28)             | mem[0x220]=0x0000000c(x16)
	//	rom_data[30] = 32'h06400893;  // addi  x17, x0, 100             | x17=0x00000064
	//	rom_data[31] = 32'h011e2023;  // sw    x17, 0(x28)              | mem[0x200]=0x00000064(x17)
	//	rom_data[32] = 32'h000e2903;  // lw    x18, 0(x28)              | x18=mem[0x200]=0x00000064
	//	rom_data[33] = 32'h00190993;  // addi  x19, x18, 1              | x19=0x00000065
	//	rom_data[34] = 32'h033e2223;  // sw    x19, 36(x28)             | mem[0x224]=0x00000065(x19)
	//	rom_data[35] = 32'h00700a13;  // addi  x20, x0, 7               | x20=0x00000007
	//	rom_data[36] = 32'h00800a93;  // addi  x21, x0, 8               | x21=0x00000008
	//	rom_data[37] = 32'h015a0863;  // beq   x20, x21, skip           | not_taken (7!=8), continue
	//	rom_data[38] = 32'h015a0b33;  // add   x22, x20, x21            | x22=0x0000000f
	//	rom_data[39] = 32'h002b0b93;  // addi  x23, x22, 2              | x23=0x00000011
	//	rom_data[40] = 32'h037e2423;  // sw    x23, 40(x28)             | mem[0x228]=0x00000011(x23)

	//	// skip (0x00a4):
	//	rom_data[41] = 32'h00000c17;  // auipc x24, 0                   | x24=0x000000a4
	//	rom_data[42] = 32'h01cc0c13;  // addi  x24, x24, 28             | x24=0x000000c0
	//	rom_data[43] = 32'hffcc00e7;  // jalr  x1, x24, -4               | x1=0x000000b0(ret), jump=0x000000bc

	//	// loop (0x00b8):
	//	rom_data[44] = 32'h00008d13;  // addi  x26, x1, 0               | x26=0x000000b0
	//	rom_data[45] = 32'h03ae2623;  // sw    x26, 44(x28)             | mem[0x22c]=0x000000b0(x26)
	//	rom_data[46] = 32'h00000063;  // beq   x0, x0, loop             | branch_taken, jump=0x00b8

	//	// func (0x00bc):
	//	rom_data[47] = 32'h12300513;  // addi  x10, x0, 0x123           | x10=0x00000123
	//	rom_data[48] = 32'h00008067;  // jalr  x0, x1, 0                | jump=0x000000b0 (return) 600ns

	//end

	always @(*) begin
		inst = rom_data[addr[9:2]];	//read, word aligned
	end

endmodule