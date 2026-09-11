module Program_Counter(
	input clk,
	input rst,
	input [31:0] PC_in,
	output reg [31:0] PC_out
);
	always @(posedge clk or posedge rst) begin
		if(rst)
			PC_out <= 32'b0;
		else
			PC_out <= PC_in; 
	end
endmodule


//PC+4

module PCplus4(
	input wire[31:0] pc_in,
	output wire[31:0] pc_plus4
);

	assign pc_plus4 = pc_in + 4;

endmodule



//IMEM Instruction Memory

module imem(
	input clk, 
	input rst,
	input [31:0] addr,
	output [31:0] instruction
);
	reg[31:0] mem [0:1023];
	integer i;
	always @(posedge clk or posedge rst)
	begin
		if(rst) begin
			for(i = 0; i < 1024; i = i + 1) begin
				mem[i] <= 32'b0;
			end
		end
	end
	assign instruction = mem[addr[31:2]];
endmodule



//registers

module registers(
	input clk, rst, regWrite,
	input [4:0] rs1, rs2, rd,
	input [31:0] write_data,
	output[31:0] read_data1, read_data2
);
	reg [31:0] registers[31:0];
	integer i;
	always @(posedge clk or posedge rst)
	begin
		if(rst) begin
			for(i =0; i < 32; i = i + 1) begin
				registers[i] <= 32'b0;
			end
		end
		else if (regWrite && rd != 0) begin
			registers[rd] <= write_data;
		end
	end
	assign read_data1 = registers[rs1];
	assign read_data2 = registers[rs2];
endmodule



// Immediate generator

module immGen(
	input [6:0] opcode,
	input [31:0] instruction,
	output reg [31:0] immExt
);
	always @(*) begin
		case(opcode)
			7'b0000011 : immExt = {{20{instruction[31]}}, instruction[31:20]};
			7'b0100011 : immExt = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
			7'b1100011 : immExt = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
			7'b0010011 : immExt = {{20{instruction[31]}}, instruction[31:20]};
			7'b1101111 : immExt = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};  // jal
			7'b0110111 : immExt = {instruction[31:12], 12'b0};  // lui
			7'b0010111 : immExt = {instruction[31:12], 12'b0};  // auipc
			default: immExt = 32'b0;
		endcase
	end
endmodule


//control

module control_unit(
	input [6:0] instruction,
	output reg branch, memRead, memtoReg, memWrite, aluSrc, regWrite, jump,
	output reg [2:0] aluOp,
	output reg [1:0] aluASrc  
);
	always @(*) begin
		aluASrc = 2'b00;
		jump = 1'b0;
		case(instruction)
			7'b0110011: {aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b001000_010; // R
			7'b0000011: {aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b111100_000; // lw
			7'b0100011: {aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b100010_000; // sw
			7'b1100011: {aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b000001_001; // beq
			7'b0010011: {aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b101000_011; // addi etc
			7'b1101111: begin  // jal
				{aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b001000_000;
				jump = 1'b1;
			end
			7'b0110111: begin  // lui
				{aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b101000_000;
				aluASrc = 2'b01;
			end
			7'b0010111: begin  // auipc
				{aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b101000_000;
				aluASrc = 2'b10;
			end
			default: {aluSrc, memtoReg, regWrite, memRead, memWrite, branch, aluOp} = 9'b000000_000;
		endcase
	end
endmodule


// ALU
module ALU_unit(
	input [31:0] A, B, 
	input [3:0] control_in, 
	output reg [31:0] alu_result, 
	output reg zero
);
	always @(control_in or A or B) begin
		case(control_in)
			4'b0000: begin zero = 0; alu_result = A&B; end //AND
			4'b0001: begin zero = 0; alu_result = A|B; end //OR
			4'b0010: begin zero = 0; alu_result = A+B; end //ADD
			4'b0110: begin if(A==B) zero = 1; else zero = 0; alu_result = A-B; end //SUBTRACT
			default: begin zero = 0; alu_result = 32'b0; end
		endcase
	end
endmodule



// ALU Control
module ALU_control(
	input [2:0] aluOp,
	input fun7,
	input [2:0] fun3,
	output reg [3:0] control_out
);

	always@(*) begin
		case(aluOp)
			3'b000: control_out = 4'b0010; // lw/sw -> add, ignore funct fields
			3'b001: control_out = 4'b0110; // beq -> subtract, ignore funct fields
			3'b010: begin // R-type -> decode funct7/funct3
				case({fun7, fun3})
					4'b0_000: control_out = 4'b0010; // add
					4'b1_000: control_out = 4'b0110; // sub
					4'b0_111: control_out = 4'b0000; // and
					4'b0_110: control_out = 4'b0001; // or
					default:  control_out = 4'b0000;
				endcase
			end
			3'b011: begin // I-type ALU immediate -> decode funct3 only, fun7 is not valid here
				case(fun3)
					3'b000: control_out = 4'b0010; // addi -> add
					3'b110: control_out = 4'b0001; // ori -> or
					3'b111: control_out = 4'b0000; // andi -> and
					default: control_out = 4'b0000;
				endcase
			end
			default: control_out = 4'b0000;
		endcase
	end
endmodule



//Data Memory
module data_Memory(
	input clk, rst, memWrite, memRead,
	input [31:0] readAddress, writeData,
	output [31:0] memData_out
);
	integer k;
	reg [31:0] D_memory[0:63];
	wire [5:0] widx = readAddress[7:2];

	always @(posedge clk or posedge rst) begin
		if(rst) begin
			for(k = 0; k < 64; k = k + 1) begin
				D_memory[k] <= 32'b0;
			end
		end
		else if (memWrite) begin
			D_memory[widx] <= writeData;
		end
	end
	assign memData_out = memRead ? D_memory[widx] : 32'b0;
endmodule

module branch_unit(
	input branch,
	input [2:0] fun3,
	input [31:0] rd1, rd2,
	output reg take_branch
);
	reg cond;
	always @(*) begin
		case(fun3)
			3'b000: cond = (rd1 == rd2);                      // beq
			3'b001: cond = (rd1 != rd2);                      // bne
			3'b100: cond = ($signed(rd1) <  $signed(rd2));    // blt
			3'b101: cond = ($signed(rd1) >= $signed(rd2));    // bge
			3'b110: cond = (rd1 <  rd2);                      // bltu
			3'b111: cond = (rd1 >= rd2);                      // bgeu
			default: cond = 1'b0;
		endcase
		take_branch = branch & cond;
	end
endmodule


//MUX
module mux1(
	input sel1, 
	input [31:0] A1, B1, 
	output [31:0] mux1_out
);
	assign mux1_out = (sel1 == 1'b0) ? A1 : B1;
endmodule
//MUX2
module mux2(
	input sel2, 
	input [31:0] A2, B2, 
	output [31:0] mux2_out
);
	assign mux2_out = (sel2 == 1'b0) ? A2 : B2;
endmodule
//MUX3
module mux3(
	input sel3, 
	input [31:0] A3, B3, 
	output [31:0] mux3_out
);
	assign mux3_out = (sel3 == 1'b0) ? A3 : B3;
endmodule

module muxA(
	input [1:0] sel,
	input [31:0] rd1, pc,
	output reg [31:0] out
);
	always @(*) begin
		case(sel)
			2'b01:   out = 32'b0;
			2'b10:   out = pc;
			default: out = rd1;
		endcase
	end
endmodule

module muxJ(
	input sel,
	input [31:0] normal, pc_plus4,
	output [31:0] out
);
	assign out = sel ? pc_plus4 : normal;
endmodule

//AND
module AND_logic(
	input branch, zero,
	output and_out
);
	assign and_out = branch & zero;
endmodule


//Adder

module Adder(
	input [31:0] in_1, in_2,
	output [31:0] sum
);
	assign sum = in_1 + in_2;
endmodule


module top(
	input clk, rst
);

	wire [31:0] PC_top, PC_plus4_top, PC_in_top;
	wire [31:0] instruction_top, alu_A_top, memData_out_top, write_data_top, ALU_mux_top, mux3_out_top, rd1_top, rd2_top, alu_result_top;
	wire regWrite_top, memWrite_top, memRead_top, aluSrc_top, branch_top, alu_zero_top, and_out_top, memtoReg_top, jump_top;
	wire [2:0] aluOp_top;
	wire [3:0] aluControl_top;
	wire [31:0] immExt_top;
	wire [31:0] adder_sum_top;
	wire [1:0] aluASrc_top;
	//PC (ok)
	Program_Counter PC(.clk(clk), .rst(rst), .PC_in(PC_in_top), .PC_out(PC_top));
	//PC Adder (ok)
	PCplus4 PC_adder(.pc_in(PC_top), .pc_plus4(PC_plus4_top));
	//Instruction Memory (ok)
	imem Inst_Memory(.clk(clk), .rst(rst), .addr(PC_top), .instruction(instruction_top));
	//Control (ok)
	control_unit control(.instruction(instruction_top[6:0]), .branch(branch_top), .memRead(memRead_top), .memtoReg(memtoReg_top), .memWrite(memWrite_top), .aluSrc(aluSrc_top), .regWrite(regWrite_top),.jump(jump_top), .aluOp(aluOp_top), .aluASrc(aluASrc_top));
	//Registers (ok)
	registers registers(.clk(clk), .rst(rst), .regWrite(regWrite_top), .rs1(instruction_top[19:15]), .rs2(instruction_top[24:20]), .rd(instruction_top[11:7]), .write_data(write_data_top), .read_data1(rd1_top), .read_data2(rd2_top));
	//Immediate Generator (ok)
	immGen immGen(.opcode(instruction_top[6:0]), .instruction(instruction_top), .immExt(immExt_top));
	//ALU Control (ok)
	ALU_control ALU_control(.aluOp(aluOp_top), .fun7(instruction_top[30]), .fun3(instruction_top[14:12]), .control_out(aluControl_top));
	//ALU (ok)
	ALU_unit ALU_unit(.A(alu_A_top), .B(ALU_mux_top), .control_in(aluControl_top), .alu_result(alu_result_top), .zero(alu_zero_top));
	//ALU Mux (ok)
	mux1 ALU_mux(.sel1(aluSrc_top), .A1(rd2_top), .B1(immExt_top), .mux1_out(ALU_mux_top));
	//Data Memory
	data_Memory data_Memory(.clk(clk), .rst(rst), .memWrite(memWrite_top), .memRead(memRead_top), .readAddress(alu_result_top), .writeData(rd2_top), .memData_out(memData_out_top));
	//Adder (ok)
	Adder adder(.in_1(PC_top), .in_2(immExt_top), .sum(adder_sum_top));
	//PC_in MUX (ok)
	mux2 mux2(.sel2(and_out_top | jump_top), .A2(PC_plus4_top), .B2(adder_sum_top), .mux2_out(PC_in_top));
	// Data Memory MUX (ok)
	mux3 mux3(.sel3(memtoReg_top), .A3(alu_result_top), .B3(memData_out_top), .mux3_out(mux3_out_top));
	muxJ J_mux(.sel(jump_top), .normal(mux3_out_top), .pc_plus4(PC_plus4_top), .out(write_data_top));
	//MUX A (ok)
	muxA A_mux(.sel(aluASrc_top), .rd1(rd1_top), .pc(PC_top), .out(alu_A_top));
	//Branch
	branch_unit branch_unit(.branch(branch_top), .fun3(instruction_top[14:12]), .rd1(rd1_top), .rd2(rd2_top), .take_branch(and_out_top));
endmodule



//testbench
module tb_top;

reg clk, rst;
top uut(.clk(clk), .rst(rst));

initial begin
	$dumpfile("waveform.vcd");
	$dumpvars(0, tb_top);

	clk = 0;
	rst = 1;
	#12;                 // hold reset clear of any clk edge (period is 10)
	rst = 0;

	// load test program / initial data after the reset-clear completes
	$readmemh("program.hex", uut.Inst_Memory.mem);
	$readmemh("data.hex", uut.data_Memory.D_memory);

	#400;
	$finish;
end

always #5 clk = ~clk;

initial
	$monitor("t=%0t PC=%h instr=%h x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d x10=%0d x11=%0d x12=%0d x13=%0d x14=%0d x15=%0d",
		$time, uut.PC_top, uut.instruction_top,
		uut.registers.registers[1], uut.registers.registers[2],
		uut.registers.registers[3], uut.registers.registers[4],
		uut.registers.registers[5],
		uut.registers.registers[10], uut.registers.registers[11],
		uut.registers.registers[12], uut.registers.registers[13],
		uut.registers.registers[14], uut.registers.registers[15]);

endmodule