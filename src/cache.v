`ifndef _cache
`define _cache

`include "defines.v"

/////////////////////////////
//                         //
//   Direct Mapped Cache   //
//                         //
/////////////////////////////
module cache (
	input wire clk,
	input wire reset,
	input wire [31:0] addr,
	input wire do_read,
	input wire is_byte,
	input wire do_write,
	input wire [31:0] data_in,
	output reg [31:0] data_out = 0,
	output reg hit = 0,
	// Memory ports
	output reg mem_write_req = 0,
	output reg [31:0] mem_write_addr = 0,
	output reg [WIDTH-1:0] mem_write_data = 0,
	input wire mem_write_ack,
	output reg mem_read_req = 0,
	output reg [31:0] mem_read_addr = 0,
	input wire [WIDTH-1:0] mem_read_data,
	input wire mem_read_ack
);

parameter WIDTH = `MEMORY_WIDTH; // Bits in cache line
parameter DEPTH = 4; // Number of cache lines
localparam WB   = $clog2(WIDTH) - 3; // Width bits
localparam DB   = $clog2(DEPTH); // Depth bits

parameter ALIAS = "cache";

// address = tag | index | offset
wire [WB-1:0]     offset = addr[WB-1:0];
wire [DB-1:0]     index  = addr[WB+DB-1:WB];
wire [31-WB-DB:0] tag    = addr[31:WB+DB];

wire [DB-1:0]     mem_read_index = mem_read_addr[WB+DB-1:WB];
wire [31-WB-DB:0] mem_read_tag   = mem_read_addr[31:WB+DB];

reg [DEPTH-1:0]  validbits = {DEPTH{1'b0}};
reg [DEPTH-1:0]  dirtybits = {DEPTH{1'b0}};
reg [31-WB-DB:0] tags [0:DEPTH-1];
reg [WIDTH-1:0]  lines [0:DEPTH-1];

wire [WIDTH-1:0] line_out = lines[index];
wire [31:0]      word_out = (WIDTH == 32) ?
	line_out :
	line_out[(addr[WB-1:2]+1)*32-1-:32];
wire [7:0]       byte_out = line_out[(offset+1)*8-1-:8];

// Async hit signal, internal
wire hit_int = tags[index] == tag && validbits[index];
wire do_sth = do_read | do_write;

// Handle requests
always @(mem_write_req, mem_write_ack, mem_read_req, mem_read_ack) begin
	if (mem_write_ack) mem_write_req = 1'b0;
	if (mem_read_ack & ~mem_write_req) begin
		`INFO(("[%s] Fill %x <= %x", ALIAS, mem_read_addr[15:0], mem_read_data))
		lines[mem_read_index]     = mem_read_data;
		tags[mem_read_index]      = mem_read_tag;
		validbits[mem_read_index] = 1'b1;
		dirtybits[mem_read_index] = 1'b0;
		mem_read_req = 1'b0;
	end
end

always @* if (hit) begin
	if (is_byte) data_out = {24'h000000, byte_out};
	else data_out <= word_out;
end else data_out <= 32'h00000000;

always @* if (~do_sth | reset)
	hit <= 1'b0;
else hit <= hit_int;

always @(posedge clk) begin
	if (reset) begin
		validbits <= {DEPTH{1'b0}};
		dirtybits <= {DEPTH{1'b0}};
		mem_write_req  <= 0;
		mem_write_addr <= 0;
		mem_write_data <= 0;
		mem_read_req   <= 0;
		mem_read_addr  <= 0;
	end else begin
		if (do_sth) begin
			if (hit_int) begin
				if (do_write) begin
					if (is_byte) lines[index][(offset+1)*8-1-:8] = data_in[7:0];
					else if (WIDTH == 32) lines[index] = data_in;
					else lines[index][(addr[WB-1:2]+1)*32-1-:32] = data_in;
					dirtybits[index] = 1'b1;
					`INFO(("[%s] Write %x <= %x", ALIAS, addr[15:0], data_in))
				end else `INFO(("[%s] Read %x => %x", ALIAS, addr[15:0], data_out))
			end else if (~mem_read_req & ~mem_write_req) begin
				`INFO(("[%s] Miss %x", ALIAS, addr[15:0]))
				// Save line if necessary
				if (validbits[index] & dirtybits[index]) begin
					mem_write_addr = {tags[index], index, {WB{1'b0}}};
					mem_write_data = lines[index];
					`INFO(("[%s] Evict %x => %x", ALIAS, mem_write_addr[15:0], mem_write_data))
					mem_write_req = 1'b1;
				end
				validbits[index] = 1'b0;
				// Memory request
				mem_read_addr = {tag, index, {WB{1'b0}}};
				mem_read_req = 1'b1;
			end
		end
	end
end

endmodule

`endif
