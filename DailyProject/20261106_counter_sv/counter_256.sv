`timescale 1ns / 1ps

module counter_256 (
    input logic clk,
    input logic rst,
    input logic mode,
    input logic run_stop,
    input logic clear,
    output logic [7:0] counter
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter <= 0;
        end else begin
            if (run_stop) begin
                if (!mode) begin  //상승
                    counter <= counter + 1;
                end else begin  //하강
                    counter <= counter - 1;
                end
            end
        end
    end
endmodule
