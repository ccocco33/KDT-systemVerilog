module top;
	task automatic by_value(input int x);
		x = x +10;
		$display("x = %d",x);
		
	endtask
	task automatic by_output(input int x, output int y );
		y = x +10;
		$display("y = %d",y);

	endtask
	task automatic by_ref(ref int x);
		x = x +10;
	endtask

	function automatic int sum(const ref int arr[4]);
		sum = 0;

		foreach (arr[i])sum += arr[i];
	endfunction
	int a = 1, r;
	int data[4] = '{1,2,3,4};

	initial begin

		by_value(a);
		$display("after by_value a = % d",a);
		by_output(a,r);

		$display("after by_output a = % d, r = %d",a,r);
		by_ref(a);

		$display("after by_ref a = %d",a);
		$display(" sum = %d",sum(data));

		$finish;
	end
endmodule
