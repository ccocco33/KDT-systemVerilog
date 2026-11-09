`timescale 1ns / 1ps
module ram_ip_sv (
    input logic clk,
    input logic [5:0] addr,
    input logic [7:0] wdata,
    input logic we,
    output logic [7:0] rdata
);

    //we 1 일땐 저장하고싶고 0일땐 출력하고 싶음
    logic [7:0] ram[0:63];
    assign rdata = ram[addr];

    always_ff @(posedge clk) begin
        if (we) begin
            ram[addr] <= wdata;
        end
    end
endmodule
