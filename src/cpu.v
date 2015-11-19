`ifndef _cpu
`define _cpu

`include "flipflop.v"
`include "memory.v"
`include "regfile.v"
`include "alu.v"
`include "multiplexer.v"
`include "control.v"
`include "fwdcontrol.v"
`include "alucontrol.v"

// Central Processing Unit
module cpu(
	input wire clk,
	input wire reset
);

////////////////////////
//                    //
//       Global       //
//                    //
////////////////////////

fwdcontrol fwdcontrol(
	.rs(id_instr[25:21]),
	.rt(id_instr[20:16]),
	.ex_dst(ex_wreg),
	.mem_dst(mem_wreg),
	.wb_dst(wb_wreg),
	.ex_rw(ex_regwrite & !ex_memtoreg),
	.mem_rw(mem_regwrite),
	.wb_rw(wb_regwrite),
	.ctrl_rs(fwdctrl_rs),
	.ctrl_rt(fwdctrl_rt)
);

////////////////////////
//                    //
// Instruction Fetch  //
//                    //
////////////////////////

wire [31:0] if_pc_next;
wire [31:0] if_instr;
wire [31:0] pc_in;
wire [31:0] pc_interm;
wire [31:0] pc_out;
reg pc_we = 1;
reg if_id_we = 1;

assign if_pc_next = pc_out + 4;

assign pc_interm = ex_isjump ? dst_jump : if_pc_next;
assign pc_in = pc_take_branch ? mem_pc_branch : pc_interm;

flipflop #(
	.N(32),
	.INIT(32'h0)
) pc (
	.clk(clk),
	.reset(reset),
	.we(pc_we),
	.in(pc_in),
	.out(pc_out)
);

memory imem (
	.clk(clk),
	.reset(reset),
	.addr(pc_out),
	.rdata(if_instr),
	.wdata(0),
	.memwrite(0),
	.memread(1)
);

flipflop #(.N(64)) if_id (
	.clk(clk),
	.reset(reset | ex_isjump | pc_take_branch),
	.we(if_id_we),
	.in({if_pc_next, if_instr}),
	.out({id_pc_next, id_instr})
);

////////////////////////
//                    //
// Instruction Decode //
//                    //
////////////////////////

wire [31:0] id_instr;
wire [31:0] id_pc_next;
wire id_regwrite;
wire id_regdst;
wire id_memtoreg;
wire id_memread;
wire id_memwrite;
wire id_isbranch;
wire id_aluop;
wire id_alusrc;
wire id_isjump;
wire id_islink;
wire id_jumpdst;
wire [31:0] id_imm;
wire [31:0] id_data_rs;
wire [31:0] id_data_rt;
wire [31:0] id_pc_jump;
wire [31:0] reg_rs;
wire [31:0] reg_rt;
reg id_ex_we = 1;
wire [1:0] fwdctrl_rs;
wire [1:0] fwdctrl_rt;

assign id_imm = {{16{id_instr[15]}}, id_instr[15:0]};
assign id_pc_jump = {id_pc_next[31:28], id_instr[25:0], 2'b00};
 
control control (
	.opcode(id_instr[31:26]),
	.funct(id_instr[5:0]),
	.regdst(id_regdst),
	.isbranch(id_isbranch),
	.memread(id_memread),
	.memtoreg(id_memtoreg),
	.aluop(id_aluop),
	.memwrite(id_memwrite),
	.alusrc(id_alusrc),
	.regwrite(id_regwrite),
	.isjump(id_isjump),
	.jumpdst(id_jumpdst),
	.islink(id_islink)
);

regfile regfile(
	.clk(clk),
	.reset(reset),
	.rreg1(id_instr[25:21]),
	.rreg2(id_instr[20:16]),
 	.rdata1(reg_rs),
	.rdata2(reg_rt),
	.regwrite(wb_regwrite),
	.wreg(wb_wreg),
	.wdata(wb_wdata)
);

multiplexer #(.X(4)) data_rs_mux (
	.select(fwdctrl_rs),
	.in_data({wb_wdata, mem_wdata, ex_exout, reg_rs}),
	.out_data(id_data_rs)
);

multiplexer #(.X(4)) data_rt_mux (
	.select(fwdctrl_rt),
	.in_data({wb_wdata, mem_wdata, ex_exout, reg_rt}),
	.out_data(id_data_rt)
);

flipflop #(.N(192)) id_ex (
	.clk(clk),
	.reset(reset | ex_isjump | pc_take_branch),
	.we(id_ex_we),
	.in({id_regwrite, id_memtoreg, id_memread, id_memwrite, id_isbranch,
        	id_regdst, id_aluop, id_alusrc, id_isjump, id_islink, id_jumpdst,
        	id_pc_next, id_data_rs, id_data_rt, id_imm, id_instr[31:26],
			id_pc_jump, id_instr[20:16], id_instr[15:11], id_instr[25:21]}),
	.out({ex_regwrite, ex_memtoreg, ex_memread, ex_memwrite, ex_isbranch,
        	ex_regdst, ex_aluop, ex_alusrc, ex_isjump, ex_islink, ex_jumpdst,
        	ex_pc_next, ex_data_rs, ex_data_rt, ex_imm_top, ex_funct, ex_opcode,
			ex_pc_jump, dst_rt, dst_rd, dst_rs})
);

////////////////////////
//                    //
//      Execute       //
//                    //
////////////////////////

reg ex_mem_we = 1;
wire ex_regwrite;
wire ex_memtoreg;
wire ex_memread;
wire ex_memwrite;
wire ex_isbranch;
wire ex_regdst;
wire ex_aluop;
wire [3:0] aluop;
wire ex_alusrc;
wire ex_isjump;
wire ex_islink;
wire ex_jumpdst;
wire [31:0] dst_jump;
wire [31:0] ex_pc_next;
wire [31:0] ex_data_rs;
wire [31:0] ex_data_rt;
wire [31:0] ex_imm;
wire [25:0] ex_imm_top;
wire [31:0] ex_pc_jump;
wire [4:0] dst_rt;
wire [4:0] dst_rd;
wire [4:0] dst_rs;
wire [4:0] dst_reg;
wire [4:0] ex_wreg;
wire ex_aluz;
wire ex_aluovf;
wire [31:0] alures;
wire [31:0] ex_exout;
wire [31:0] data_rt;
wire [31:0] ex_pc_branch;
wire [5:0] ex_opcode;
wire [5:0] ex_funct;

assign ex_imm = {ex_imm_top, ex_funct};

assign ex_pc_branch = ex_pc_next + (ex_imm << 2);

assign dst_jump = ex_jumpdst ? ex_data_rs : ex_pc_jump;

alucontrol alucontrol(
	.funct(ex_funct),
	.opcode(ex_opcode),
	.aluop_in(ex_aluop),
	.aluop_out(aluop)
);

assign data_rt = ex_alusrc ? ex_imm : ex_data_rt;

alu alu(
	.aluop(aluop),
	.s(ex_data_rs),
	.t(data_rt),
	.shamt(ex_imm[10:6]),
	.zero(ex_aluz),
	.overflow(ex_aluovf),
	.out(alures)
);

assign ex_exout = ex_islink ? ex_pc_next : alures;

assign dst_reg = ex_regdst ? dst_rd : dst_rt;
assign ex_wreg = ex_islink ? 5'h1f : dst_reg;

flipflop #(.N(110)) ex_mem (
	.clk(clk),
	.reset(reset | pc_take_branch),
	.we(ex_mem_we),
	.in({ex_regwrite, ex_memtoreg, ex_memread, ex_memwrite,
        	ex_isbranch, ex_pc_branch,  ex_aluovf, ex_aluz,
        	ex_exout, ex_data_rt, ex_wreg}),
	.out({mem_regwrite, mem_memtoreg, mem_memread, mem_memwrite,
        	mem_isbranch,  mem_pc_branch, mem_aluovf, mem_aluz,
        	mem_exout, mem_data_rt, mem_wreg})
);

////////////////////////
//                    //
//       Memory       //
//                    //
////////////////////////

wire [31:0] mem_pc_branch;
reg mem_wb_we = 1;
wire mem_regwrite;
wire mem_memtoreg;
wire mem_memread;
wire mem_memwrite;
wire mem_isbranch;
wire mem_aluz;
wire mem_aluovf;
wire [31:0] mem_exout;
wire [31:0] mem_data_rt;
wire [31:0] mem_memout;
wire [4:0] mem_wreg;
wire [31:0] mem_wdata;
wire pc_take_branch;

assign pc_take_branch = mem_isbranch & mem_aluz;

memory dmem (
	.clk(clk),
	.reset(reset),
	.addr(mem_exout),
	.rdata(mem_memout),
	.wdata(mem_data_rt),
	.memwrite(mem_memwrite),
	.memread(mem_memread)
);

assign mem_wdata = mem_memtoreg ? mem_memout : mem_exout;

flipflop #(.N(38)) mem_wb (
	.clk(clk),
	.reset(reset),
	.we(mem_wb_we),
	.in({mem_regwrite, mem_wdata, mem_wreg}),
	.out({wb_regwrite, wb_wdata, wb_wreg})
);


////////////////////////
//                    //
//     Write back     //
//                    //
////////////////////////



wire wb_regwrite;
wire [31:0] wb_wdata;
wire [4:0] wb_wreg;

//
//          /\_/\
//     ____/ o o \
//   /~____  =ø= /
//  (______)__m_m)
// 

endmodule

`endif
