`timescale 1ns / 1ps

module uart_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy
);
    logic b_tick;
    uart_tx U_UART_TX (.*);

    baud_tick U_BAUD_TICK (.*);


endmodule
module baud_tick (
    input  logic clk,
    input  logic rst,
    output logic b_tick
);
    localparam F_COUNT = 100_000_000 / (9600 * 16);
    bit [$clog2(F_COUNT)-1:0] counter = 0;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            counter <= 0;
            b_tick  <= 0;
        end else begin
            if (counter == F_COUNT - 1) begin
                b_tick  <= 1;
                counter <= 0;
            end else begin
                b_tick  <= 0;
                counter <= counter + 1;
            end
        end
    end

endmodule
