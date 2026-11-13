`timescale 1ns / 1ps
interface uart_interface (
    input clk
);
    logic        rst;
    logic        start;
    logic [ 7:0] tx_data;
    logic        tx;
    logic        tx_busy;
endinterface

class transaction;
    bit                     rst;
    rand bit                start;
    rand logic        [7:0] tx_data;
    rand int unsigned       interval;  //tx start interval
    logic                   tx;
    logic                   tx_busy;
    //for MON,SCB
    bit                     start_bit_error;
    bit                     stop_bit_error;
    bit                     frame_time_error;

    constraint interval_range {
        interval < 1000;}

    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d, start = %d, tx_data = %d, interval %d, tx = %d, tx_busy = %d",
            $time, name, rst, start, tx_data, interval, tx, tx_busy);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;
    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();
            tr.rst   = 0;
            tr.start = 0;

            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
    endtask
endclass

int interval_cnt = 0;

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_interface uart_vif;
    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_interface uart_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_vif = uart_vif;
    endfunction

    task preset();
        uart_vif.rst = 1;
        uart_vif.start = 0;
        uart_vif.tx_data = 0;
        repeat (2) @(negedge uart_vif.clk);
        uart_vif.rst = 0;
    endtask

    int busy_check_count = 0;
    task run();
        forever begin

        end
    endtask



endclass

class monitor;
    transaction tr_in, tr_out;
    mailbox #(transaction) mon2scb_in_mbox, mon2scb_out_mbox;
    virtual uart_interface uart_vif;

    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox,
                 virtual uart_interface uart_vif);
        this.mon2scb_in_mbox  = mon2scb_in_mbox;
        this.mon2scb_out_mbox = mon2scb_out_mbox;
        this.uart_vif         = uart_vif;
    endfunction
    parameter BAUD_TIME = (100_000_000 / 9600) * 10;
    parameter FRAME_TIME = BAUD_TIME * 10;

    task uart_receive(output logic [7:0] receive_data);

    endtask

    task run();
        forever begin
            
        end
    endtask
endclass

class scoreboard;
    transaction tr_in, tr_out;
    mailbox #(transaction) mon2scb_in_mbox, mon2scb_out_mbox;
    event gen_next_evt;

    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox, event gen_next_evt);
        this.mon2scb_in_mbox  = mon2scb_in_mbox;
        this.mon2scb_out_mbox = mon2scb_out_mbox;
        this.gen_next_evt     = gen_next_evt;

    endfunction

    task run();
        
    endtask

    task report();
        
    endtask
endclass

class environment;
    mailbox #(transaction) mon2scb_in_mbox, mon2scb_out_mbox, gen2drv_mbox;
    event gen_next_evt;
    virtual uart_interface uart_vif;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    function new(virtual uart_interface uart_vif);
        gen2drv_mbox     = new;
        mon2scb_in_mbox  = new;
        mon2scb_out_mbox = new;
        gen              = new(gen2drv_mbox, gen_next_evt);
        drv              = new(gen2drv_mbox, uart_vif);
        mon              = new(mon2scb_in_mbox, mon2scb_out_mbox, uart_vif);
        scb              = new(mon2scb_in_mbox, mon2scb_out_mbox, gen_next_evt);
    endfunction

    task run(int run_count);
        drv.preset();
        fork
            gen.run(run_count);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        scb.report();

    endtask
endclass

module tb_uart_sv ();
    parameter BAUD_TIME = (100_000_000 / 9600) * 10;
    logic clk = 0;
    uart_interface uart_if (clk);
    environment env;
    uart_sv dut (
        .clk    (clk),
        .rst    (uart_if.rst),
        .start  (uart_if.start),
        .tx_data(uart_if.tx_data),
        .tx     (uart_if.tx),
        .tx_busy(uart_if.tx_busy)
    );
    always #5 clk = ~clk;
    initial begin
        /*
        clk = 0;
        uart_if.rst = 1;
        uart_if.start = 0;
        uart_if.tx_data = 8'haa;
        #10;
        uart_if.rst = 0;
        #10;
        uart_if.start = 1;
        #10;
        uart_if.start = 0;
        #(BAUD_TIME * 10);
        #100;
        */
        env = new(uart_if);
        env.run(100);
        $finish;


    end
endmodule
