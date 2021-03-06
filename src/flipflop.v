`ifndef _flipflop
`define _flipflop

// Flip Flop
//
// Saves data during one clock cycle
//
// Description:
//
// With this module you can save data during one clock cycle.
// The data can have variable size, depending on the module
// instantiation. Data is written on the rising edge of the clock.
//
// Ports:
// clk - Clock signal
// reset - Reset signal
// we - Write enable
// in - Input data
// out - Output data
//
// Parameters:
// N - Data size
// INIT - Default value (set on reset)
module flipflop(
	input wire clk,
	input wire reset,
	input wire we,
	input wire [N-1:0] in,
	output reg [N-1:0] out = {N{1'b0}}
);

parameter N = 1;
parameter INIT = {N{1'b0}};

always @(posedge clk) begin
	if (reset)
		out <= INIT;
	else if (we)
		out <= in;
end

endmodule

`endif
