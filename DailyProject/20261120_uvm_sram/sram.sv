module sram (
	input		logic				clk,
	input		logic	[7:0] addr,
	input		logic	[7:0] wdata,
	input		logic				we,
	output	logic	[7:0] rdata
);
	logic [7:0] ram[0:255];

	always_ff @(posedge clk) begin
		if(we) begin
			ram[addr] <= wdata;
		end else begin
			rdata <= ram[addr];
		end
	end

endmodule
