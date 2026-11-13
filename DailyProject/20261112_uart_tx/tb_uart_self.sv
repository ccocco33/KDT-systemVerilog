`timescale 1ns / 1ps
interface uart_interface (
    input clk
);
    logic       rst;
    logic       start;
    logic [7:0] tx_data;
    logic       tx;
    logic       tx_busy;
endinterface

class transaction;
    // logic            rst;
    // rand logic       start;
    rand logic [7:0] tx_data;
    // logic            tx;
    // logic            tx_busy;
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv;
    event gen_next_evt;
    function new(mailbox#(transaction) gen2drv, event gen_next_evt);
        this.gen2drv      = gen2drv;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();


            gen2drv.put(tr);

            @(gen_next_evt);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv;
    virtual uart_interface uart_vif;
    function new(mailbox#(transaction) gen2drv,
                 virtual uart_interface uart_vif);
        this.gen2drv  = gen2drv;
        this.uart_vif = uart_vif;
    endfunction

    task preset();
        uart_vif.rst = 1;
        uart_vif.start = 0;
        uart_vif.tx_data = 0;
        @(negedge uart_vif.clk);
        @(negedge uart_vif.clk);
        uart_vif.rst = 0;
    endtask


    task run();
        forever begin
            @(negedge uart_vif.clk);

            if (!uart_vif.tx_busy) begin
                gen2drv.get(tr);
                uart_vif.start   = 1;
                uart_vif.tx_data = tr.tx_data;
            end else begin
                uart_vif.start = 0;
            end
        end
    endtask



endclass

class monitor;
    transaction tr_in;
    transaction tr_out;
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
    bit   [3:0] counter   = 0;
    logic [7:0] ouput_tx;
    task run();
        forever begin


            @(posedge uart_vif.clk);
            #1;
            if (uart_vif.start & !uart_vif.tx_busy) begin
                tr_in = new;
                tr_in.tx_data = uart_vif.tx_data;
                mon2scb_in_mbox.put(tr_in);
            end
            if (uart_vif.tx_busy) begin
                //tx(start+data8bit+stop)
                if (counter == 0) begin
                    //
                    #(BAUD_TIME / 2);
                    if (uart_vif.tx == 0) counter++;
                    tr_out = new;
                end else if (counter < 9) begin
                    #(BAUD_TIME);
                    ouput_tx = {uart_vif.tx, ouput_tx[7:1]};
                    counter++;
                end else if (counter == 9) begin
                    if (uart_vif.tx == 1) begin
                        counter = 0;
                        tr_out.tx_data = ouput_tx;
                        mon2scb_out_mbox.put(tr_out);
                    end
                end
            end
        end
    endtask
endclass

class scoreboard;
    transaction tr_in;
    transaction tr_out;
    mailbox #(transaction) mon2scb_in_mbox, mon2scb_out_mbox;
    event gen_next_evt;
    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox, event gen_next_evt);
        this.mon2scb_in_mbox  = mon2scb_in_mbox;
        this.mon2scb_out_mbox = mon2scb_out_mbox;
        this.gen_next_evt     = gen_next_evt;
    endfunction
    task run();
        forever begin
            mon2scb_in_mbox.get(tr_in);
            mon2scb_out_mbox.get(tr_out);

            if (tr_in.tx_data === tr_out.tx_data) begin
            end
            ->gen_next_evt;
        end
    endtask
endclass

class environment;
    transaction tr;
    mailbox #(transaction) mon2scb_in_mbox, mon2scb_out_mbox, gen2drv;
    event gen_next_evt;
    virtual uart_interface uart_vif;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    function new(virtual uart_interface uart_vif);

        gen2drv          = new;
        mon2scb_in_mbox  = new;
        mon2scb_out_mbox = new;
        gen              = new(gen2drv, gen_next_evt);
        drv              = new(gen2drv, uart_vif);
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

    endtask
endclass

module tb_uart_sv ();
    parameter BAUD_TIME = (100_000_000 / 9600) * 10;
    logic clk = 0;
    uart_interface uart_if (clk);
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
        $finish;


    end
endmodule