`timescale 1ns / 1ps

module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx_busy,
    output logic       tx
);
    logic w_b_tick;
    tx_sv U_TX_SV (
        .*,
        .b_tick(w_b_tick)
    );
    baud_tick U_BAUD_TICK (
        .*,
        .b_tick(w_b_tick)
    );
endmodule

module tx_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    input  logic       b_tick,
    output logic       tx_busy,
    output logic       tx
);
    logic tx_busy_next, tx_next;
    bit [7:0] data_send_cnt, data_send_cnt_next = 0;
    bit [7:0] data_frame, data_frame_next = 8'b0;
    bit [15:0] b_tick_cnt, b_tick_cnt_next = 0;

    //system verilog에서는 시뮬레이션에 텍스트가 뜨게 할 수 있다. 
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_tx;
    state_tx c_state, n_state;
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            tx_busy <= 0;
            tx <= 1;
            data_send_cnt <= 0;
            b_tick_cnt <= 0;
            data_frame <= 0;
            c_state <= IDLE;
        end else begin
            tx_busy       <= tx_busy_next;
            tx            <= tx_next;
            data_send_cnt <= data_send_cnt_next;
            b_tick_cnt    <= b_tick_cnt_next;
            data_frame    <= data_frame_next;
            c_state       <= n_state;

        end
    end


    always_comb begin
        tx_busy_next = tx_busy;
        tx_next = tx;
        data_send_cnt_next = data_send_cnt;
        b_tick_cnt_next = b_tick_cnt;
        data_frame_next = data_frame;
        n_state = c_state;
        case (c_state)
            IDLE: begin
                tx_next = 1;
                tx_busy_next = 0;
                if (tx_start) begin
                    n_state = START;
                    data_frame_next =  tx_data;
                end
            end
            START: begin
                tx_next = 0;
                tx_busy_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_frame[0];
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        data_frame_next = data_frame >> 1;
                        b_tick_cnt_next = 0;
                        if (data_send_cnt == 7) begin
                            n_state = STOP;
                            data_send_cnt_next = 0;
                        end else begin
                            data_send_cnt_next = data_send_cnt + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
        endcase
    end



endmodule

module baud_tick (
    input  logic clk,
    input  logic rst,
    output logic b_tick
);
    localparam F_COUNT = 100_000_000 / (9600*16);
    bit [$clog2(F_COUNT)-1:0] counter = 0;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            b_tick <= 0;
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
