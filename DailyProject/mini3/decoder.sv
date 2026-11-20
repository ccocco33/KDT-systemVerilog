`timescale 1ns / 1ps
module ascii_decoder (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx_done,
    input  logic [7:0] ascii,
    output logic       tx_start,
    output logic [7:0] bin
);
    logic [7:0] bin_next;
    logic tx_start_next;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            bin <= 8'h0;
            tx_start <= 0;
        end else begin
            bin <= bin_next;
            tx_start <= tx_start_next;
        end
    end

    always @(*) begin
        tx_start_next = 1'b0;
        bin_next = bin;
        if (rx_done) begin
            tx_start_next = 1'b1;
            case (ascii)
                8'h30: bin_next = 8'h0;
                8'h31: bin_next = 8'h1;
                8'h32: bin_next = 8'h2;
                8'h33: bin_next = 8'h3;
                8'h34: bin_next = 8'h4;
                8'h35: bin_next = 8'h5;
                8'h36: bin_next = 8'h6;
                8'h37: bin_next = 8'h7;
                8'h38: bin_next = 8'h8;
                8'h39: bin_next = 8'h9;

                //대문자,소문자
                8'h41, 8'h61: bin_next = 8'ha;
                8'h42, 8'h62: bin_next = 8'hb;
                8'h43, 8'h63: bin_next = 8'hc;
                8'h44, 8'h64: bin_next = 8'hd;
                8'h45, 8'h65: bin_next = 8'he;
                8'h46, 8'h66: bin_next = 8'hf;

                default: bin_next = 8'hFF;
            endcase
        end
    end

endmodule
