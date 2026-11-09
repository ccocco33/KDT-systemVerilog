`timescale 1ns / 1ps


interface counter_interface (
    input clk
);
    logic rst;
    logic mode;
    logic run_stop;
    logic clear;
    logic [7:0] counter;

    property rst_zero;
        @(posedge clk) rst |-> (counter == 8'd0);
    endproperty

    a_rst_zero :
    assert property (rst_zero)
    else begin
        $display("[Interface] reset = %d counter value error ! counter = %d",
                 rst, counter);
    end
endinterface

class transaction;
    rand bit rst;
    rand bit mode;
    rand bit run_stop;
    rand bit clear;
    logic [7:0] counter;

    static bit reg_rst, reg_mode, reg_clear = 0;
    static bit reg_run_stop = 1;

    static bit [1:0] rand_counter = 0;

    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d,mode= %d, run_stop= %d, clear = %d, counter = %d, rand_counter = %d",
            $time, name, rst, mode, run_stop, clear, counter, rand_counter);
    endfunction

    constraint rand_3clk {
        if (rand_counter == 0) {
            rst dist {
                0 := 10,
                1 := 1
            };
            clear dist {
                0 := 100,
                1 := 1
            };
            mode dist {
                0 :/ 9,
                1 :/ 1
            };
        } else
        if (rand_counter != 0) {
            rst == reg_rst;
            mode == reg_mode;
            run_stop == reg_run_stop;
            clear == reg_clear;
        }
    }
    function void post_randomize();
        reg_rst = rst;
        reg_mode = mode;
        reg_run_stop = run_stop;
        reg_clear = clear;
        rand_counter = (rand_counter == 2) ? 0 : rand_counter + 1;
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;
    // to control for generator task run
    bit enable = 1;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run();
        while (enable) begin
            tr = new;
            assert (tr.randomize())
            else $display("[GEN] tr.randomized error!");
            //mode = rand run_stop =rand,clear =rand
            // tr.rst = 0;
            // tr.mode = 0;
            // tr.run_stop = 1;
            // tr.clear = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
    endtask

//     task run();
//         while (enable) begin
//             @(gen_next_evt);
//             tr = new;
//             assert (tr.randomize())
//             else $display("[GEN] tr.randomized error!");
//             //mode = rand run_stop =rand,clear =rand
//             // tr.rst = 0;
//             // tr.mode = 0;
//             // tr.run_stop = 1;
//             // tr.clear = 0;
//             gen2drv_mbox.put(tr);
//             tr.debug_print("GEN");
//         end
//     endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual counter_interface counter_vif;
    event gen_next_evt;


    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt,
                 virtual counter_interface counter_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
        this.counter_vif  = counter_vif;
    endfunction

    task preset();
        counter_vif.rst = 1;
        counter_vif.mode = 0;
        counter_vif.run_stop = 0;
        counter_vif.clear = 0;
        @(negedge counter_vif.clk);
        @(negedge counter_vif.clk);
        counter_vif.rst = 0;
    endtask

    task run();
        forever begin
            @(negedge counter_vif.clk);
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            counter_vif.rst = tr.rst;
            counter_vif.mode = tr.mode;
            counter_vif.run_stop = tr.run_stop;
            counter_vif.clear = tr.clear;
            ->gen_next_evt;

        end
    endtask

    // task run();
    //     forever begin
    //         @(negedge counter_vif.clk);
    //         ->gen_next_evt;
    //         gen2drv_mbox.get(tr);
    //         tr.debug_print("DRV");
    //         counter_vif.rst = tr.rst;
    //         counter_vif.mode = tr.mode;
    //         counter_vif.run_stop = tr.run_stop;
    //         counter_vif.clear = tr.clear;

    //     end
    // endtask

endclass  //drive


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual counter_interface counter_vif;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual counter_interface counter_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.counter_vif  = counter_vif;
    endfunction

    task run();
        forever begin

            @(posedge counter_vif.clk);
            tr          = new();
            tr.rst      = counter_vif.rst;
            tr.mode     = counter_vif.mode;
            tr.run_stop = counter_vif.run_stop;
            tr.clear    = counter_vif.clear;
            tr.counter  = counter_vif.counter;
            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask
endclass
class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    logic [7:0] expected_count = 0;
    int match_cnt = 0, mismatch_cnt = 0, total_cnt = 0;
    int
        pass_clear_cnt,
        pass_up_cnt,
        pass_down_cnt,
        pass_run_cnt,
        pass_stop_cnt = 0;
    int
        fail_clear_cnt,
        fail_up_cnt,
        fail_down_cnt,
        fail_run_cnt,
        fail_stop_cnt = 0;
    bit reg_mode, reg_run_stop, reg_clear, reg_rst = 0;
    bit first_flag = 1;
    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction


    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");

            if (first_flag) begin
                first_flag = 0;
            end else if (tr.rst & !reg_rst) begin
                total_cnt++;
                expected_count = 0;
                if (expected_count == tr.counter) begin
                    $display("[count: %d][pass] e: %d, t: %d", total_cnt,
                             expected_count, tr.counter);
                    pass_clear_cnt++;

                end else begin
                    fail_clear_cnt++;
                    $display("[count: %d][fail] e: %d, t: %d", total_cnt,
                             expected_count, tr.counter);
                end
            end else if (!reg_rst & !reg_clear) begin
                total_cnt++;
                if (reg_run_stop) begin
                    if (reg_mode) begin  //감소
                        expected_count--;
                    end else begin  //증가
                        expected_count++;
                    end
                end
                if (expected_count == tr.counter) begin
                    match_cnt++;
                    $display("[count: %d][pass] e: %d, t: %d", total_cnt,
                             expected_count, tr.counter);
                    if (reg_run_stop & reg_mode) begin  // run & down
                        pass_run_cnt++;
                        pass_down_cnt++;
                    end else if (!reg_run_stop & reg_mode) begin  //stop & down
                        pass_stop_cnt++;
                    end else if (reg_run_stop & !reg_mode) begin  //run & up
                        pass_run_cnt++;
                        pass_up_cnt++;
                    end else if (!reg_run_stop & !reg_mode) begin  //stop & up
                        pass_stop_cnt++;
                    end
                end else begin
                    mismatch_cnt++;
                    if (reg_rst | reg_clear) begin
                        fail_clear_cnt++;
                    end else if (reg_run_stop & reg_mode) begin  // run & down
                        fail_run_cnt++;
                        fail_down_cnt++;
                    end else if (!reg_run_stop & reg_mode) begin  //stop & down
                        fail_stop_cnt++;
                    end else if (reg_run_stop & !reg_mode) begin  //run & up
                        fail_run_cnt++;
                        fail_up_cnt++;
                    end else if (!reg_run_stop & !reg_mode) begin  //stop & up
                        fail_stop_cnt++;
                    end
                    $display("[count: %d][fail] e: %d, t: %d", total_cnt,
                             expected_count, tr.counter);
                end

            end else begin  //reset or clear
                total_cnt++;
                expected_count = 0;
                if (expected_count == tr.counter) begin
                    $display("[count: %d][pass] e: %d, t: %d", total_cnt,
                             expected_count, tr.counter);
                    pass_clear_cnt++;

                end else begin
                    fail_clear_cnt++;
                    $display("[count: %d][fail] e: %d, t: %d", total_cnt,
                             expected_count, tr.counter);
                end

            end
            reg_mode = (tr.mode) ? 1 : 0;
            reg_run_stop = (tr.run_stop) ? 1 : 0;
            reg_clear = (tr.clear) ? 1 : 0;
            reg_rst = (tr.rst) ? 1 : 0;
        end
    endtask
    task report();
        $display("======================================");
        $display("| total test             : %4d        |", total_cnt);
        $display("--------------------------------------");
        $display("| total match            : %4d        |",
                 match_cnt + pass_clear_cnt);
        $display("| total mismatch         : %4d        |",
                 mismatch_cnt + fail_clear_cnt);
        $display("|   - run/stop           : %4d        |", mismatch_cnt);
        $display("|   - reset/clear        : %4d        |", fail_clear_cnt);
        $display("=============== detail ===============");
        $display("----------- reset / clear ------------");
        $display("| reset / clear pass     : %4d        |", pass_clear_cnt);
        $display("| reset / clear fail     : %4d        |", fail_clear_cnt);
        $display("------------- run / stop -------------");
        $display("| total run/stop count   : %4d        |",
                 pass_run_cnt + pass_stop_cnt + fail_run_cnt + fail_stop_cnt);
        $display("| total run/stop pass    : %4d        |",
                 pass_run_cnt + pass_stop_cnt);
        $display("|   - run pass           : %4d        |", pass_run_cnt);
        $display("|   - stop pass          : %4d        |", pass_stop_cnt);
        $display("| total run/stop fail    : %4d        |",
                 fail_run_cnt + fail_stop_cnt);
        $display("|   - run fail           : %4d        |", fail_run_cnt);
        $display("|   - stop fail          : %4d        |", fail_stop_cnt);
        $display("------------- up / down --------------");
        $display("| total up/down count    : %4d        |",
                 pass_up_cnt + pass_down_cnt + fail_up_cnt + fail_down_cnt);
        $display("| total up/down pass     : %4d        |",
                 pass_up_cnt + pass_down_cnt);
        $display("|   - up pass            : %4d        |", pass_up_cnt);
        $display("|   - down pass          : %4d        |", pass_down_cnt);
        $display("| total up/down fail     : %4d        |",
                 fail_up_cnt + fail_down_cnt);
        $display("|   - up fail            : %4d        |", fail_up_cnt);
        $display("|   - down fail          : %4d        |", fail_down_cnt);
        $display("======================================");
    endtask

endclass


class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_evt;

    function new(virtual counter_interface counter_vif);
        mon2scb_mbox = new;
        gen2drv_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, gen_next_evt, counter_vif);
        mon = new(mon2scb_mbox, counter_vif);
        scb = new(mon2scb_mbox);
    endfunction

    task run(int run_count);
        drv.preset();
        //gen run
        gen.enable = 1;
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
        #3000;
        gen.enable = 0;
        #10;

        scb.report();
        disable fork;

    endtask

endclass

module tb_counter_sv ();
    logic clk = 0;
    environment env;
    counter_interface counter_if (clk);

    counter_256 dut (
        .clk     (clk),
        .rst     (counter_if.rst),
        .mode    (counter_if.mode),
        .run_stop(counter_if.run_stop),
        .clear   (counter_if.clear),
        .counter (counter_if.counter)
    );
    always #5 clk = ~clk;

    initial begin
        env = new(counter_if);
        env.run(256);
        $finish;
    end
endmodule

