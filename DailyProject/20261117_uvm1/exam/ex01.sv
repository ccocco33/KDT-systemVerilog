class packet ;
	int addr;
	int data;

	function new(int addr = 0,int data = 0);
		this.addr = addr;
		this.data = data;
	endfunction
	
	function void display(string name);
		$display("[%s] addr = %d, data = %d",name,addr,data);
	endfunction
endclass


module top;

	packet p1,p2,p3; //handle = NULL

	initial begin
		p1 = new(1,100);
		p1.display("P1");
		
		p2 = p1; // same obeject ,different handle
		p2.data = 200;
		p2.display("P2");//P2 addr = 1 ,data = 200;
		
		p3 = new p1; //copy p1, dynamic create P3 addr = 1,data = 200;
		p3.data = 300;
		p1.display("2)P1");
		p3.display("2)P3");

		$finish;
	end
	

endmodule
