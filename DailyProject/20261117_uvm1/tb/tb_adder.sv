module tb_adder();

reg [7:0]a,b;
wire [7:0]s;
wire c;
adder dut(
	.a(a),
	.b(b),
	.s(s),
	.c(c)
);
	initial begin
		//vcs fsdb
		$fsdbDumpfile("wave.fsdb");
		$fsdbDumpvars(0,tb_adder);
	end

	initial begin
		a = 8'd127;
		b = 8'd1;
		#10;
		$display("%d + %d =  s = %d,c = %d",a,b,s,c);
		a = 8'd255;
		b = 8'd1;
	  #10;
		$display("%d + %d =  s = %d,c = %d",a,b,s,c);
		$finish;
	
	
	end
	


endmodule


