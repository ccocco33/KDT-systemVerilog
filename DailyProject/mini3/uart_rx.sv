`timescale 1ns / 1ps

module uart_rx (
    input clk,
    input rst,
    input b_tick,
    input rx,
    output [7:0] rx_data,
    output rx_done
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] n_state, c_state;
    reg [3:0] b_tick_cnt, b_tick_cnt_next;
    reg [2:0] bit_cnt, bit_cnt_next;
    reg rx_done_reg, rx_done_next;
    reg [7:0] data_reg, data_next;
    assign rx_data = data_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state     <= IDLE;
            b_tick_cnt  <= 4'h0;
            bit_cnt     <= 3'h0;
            rx_done_reg <= 1'b0;
            data_reg    <= 8'h0;
        end else begin
            c_state     <= n_state;
            b_tick_cnt  <= b_tick_cnt_next;
            bit_cnt     <= bit_cnt_next;
            rx_done_reg <= rx_done_next;
            data_reg    <= data_next;
        end
    end
    //next, output
    always @(*) begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt;
        bit_cnt_next    = bit_cnt;
        rx_done_next    = rx_done_reg;
        data_next       = data_reg;

        // bit_cnt=3'b0;
        // data_reg=8'b0;
        // b_tick_cnt =3'b0;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 0;
                rx_done_next    = 1'b0;
                if (b_tick) begin
                    if (!rx) begin
                        n_state = START;
                    end
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt == 7) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        data_next       = 8'h00;
                        n_state         = DATA;
                        // if (!b_tick_cnt & !bit_cnt) begin
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                        // end
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        b_tick_cnt_next = 0;
                        data_next = {rx, data_reg[7:1]};
                        if (bit_cnt == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt + 1;
                            //right shift data register
                            // data_next = {1'b0,data_reg[7:1]};
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        rx_done_next = 1'b1;
                        n_state      = IDLE;
                        // if (rx) begin
                        //     n_state = IDLE;
                        //     b_tick_cnt_next = 0;
                        //     rx_done = 1'b1;
                        // end else $display("error");
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end

        endcase
    end

endmodule
