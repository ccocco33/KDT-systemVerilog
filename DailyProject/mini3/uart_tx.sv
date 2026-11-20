`timescale 1ns / 1ps

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx,
    output       tx_busy
);
    localparam [1:0] IDEL = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] c_state, n_state;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [7:0] data_reg, data_next;
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;
    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;
    //state SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= IDEL;
            bit_count_reg  <= 3'b0;
            b_tick_cnt_reg <= 0; //내가 바꿈
            data_reg       <= 8'h0;
            tx_reg         <= 1'b1;
            tx_busy_reg    <= 1'b0;
        end else begin
            c_state        <= n_state;
            bit_count_reg  <= bit_count_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            data_reg       <= data_next;
            tx_reg         <= tx_next;
            tx_busy_reg    <= tx_busy_next;
        end
    end

    //next, output
    always @(*) begin
        n_state         = c_state;
        bit_count_next  = bit_count_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        data_next       = data_reg;
        tx_next         = tx_reg;
        tx_busy_next    = tx_busy_reg;
        case (c_state)
            IDEL: begin
                tx_next      = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    bit_count_next = 0;
                    b_tick_cnt_next = 0;
                    data_next = tx_data;
                    n_state = START;
                end
            end
            START: begin
                tx_busy_next = 1'b1;  // to be transmit
                tx_next      = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg +1;
                        // bit_count_next  = 3'b0;
                        // n_state         = DATA;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                            b_tick_cnt_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            data_next = {1'b0, data_reg[7:1]};
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg +1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if(b_tick_cnt_reg == 15)n_state = IDEL;
                    else b_tick_cnt_next = b_tick_cnt_reg +1;
                end
            end
        endcase

    end

endmodule

