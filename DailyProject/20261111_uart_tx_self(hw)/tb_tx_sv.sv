`timescale 1ns / 1ps

module tb_tx_sv ();
    logic clk, rst, tx_start, tx, tx_busy;
    logic [7:0] tx_data;
    uart_tx dut (.*);
    localparam F_COUNT = 100_000_000 / (9600 * 16) * 10;  //(10ns)

    always #5 clk = ~clk;
    initial begin
        rst = 1;
        clk = 0;
        tx_start = 0;
        tx_data = 0;
        #10;
        rst = 0;
        #100;
        tx_start = 1;
        tx_data  = 8'b0101_0101;
        #10;
        tx_start = 0;
        tx_data  = 8'b0;
        
        repeat (12) #(F_COUNT * 16);

        $finish;
    end
endmodule
