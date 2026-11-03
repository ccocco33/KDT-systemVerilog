`timescale 1ns / 1ps

module adder (
    input  logic [7:0] a,     //데이터 타입 선언 안하면 wire
    input  logic [7:0] b,
    input  logic       mode,  // 0: add, 1:: sub
    output logic [7:0] s,
    output logic       c
);

    assign {c, s} = (mode) ? a - b : a + b;

    // always_comb begin
    //     {c, s} = a + b;
    // end

endmodule
