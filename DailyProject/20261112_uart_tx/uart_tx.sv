`timescale 1ns / 1ps


module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] tx_data,
    input  logic       b_tick,
    output logic       tx_busy,
    output logic       tx
);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_e;

    state_e c_state, n_state;
    logic tx_busy_next, tx_next;
    logic [7:0] data_reg, data_next = 8'b0;
    logic [2:0] bit_cnt_reg, bit_cnt_next = 0;
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next = 0;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            tx             <= 1;
            tx_busy        <= 0;
            data_reg       <= 0;
            bit_cnt_reg    <= 0;
            b_tick_cnt_reg <= 0;
        end else begin
            c_state        <= n_state;
            tx             <= tx_next;
            tx_busy        <= tx_busy_next;
            data_reg       <= data_next;
            bit_cnt_reg    <= bit_cnt_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
        end
    end

    always_comb begin

        n_state         = c_state;
        tx_next         = tx;
        tx_busy_next    = tx_busy;
        data_next       = data_reg;
        bit_cnt_next    = bit_cnt_reg;
        b_tick_cnt_next = b_tick_cnt_reg;

        case (c_state)
            IDLE: begin
                tx_next      = 1;
                tx_busy_next = 0;
                if (start) begin
                    n_state = START;
                    data_next = tx_data;
                    bit_cnt_next = 0;
                    b_tick_cnt_next = 0;
                    tx_busy_next = 1;
                end
            end
            START: begin
                tx_next = 0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                            // bit_cnt_next = 0;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_next = data_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        tx_busy_next = 0;
                        n_state = IDLE;
                        // b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule
