`ifndef _fflop
`define _fflop

module fflop(
	input wire clk,
	input wire reset,
	input wire we,
	input wire [N-1:0] in,
	output reg [N-1:0] out = {N{1'b0}});

parameter N = 1;

always @(posedge clk) begin
	if (reset)
		out <= {N{1'b0}};
	else if (we)
		out <= in;
	else
		out <= out;
end

endmodule

`endif
