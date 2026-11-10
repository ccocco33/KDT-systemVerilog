`timescale 1ns / 1ps
interface fifo_interface (
    input logic clk
);
    logic       rst;
    logic       push;
    logic       pop;
    logic [7:0] push_data;
    logic [7:0] pop_data;
    logic       empty;
    logic       full;

    property rst_zero;
        @(posedge clk) rst |-> ((empty == 1'b1) & (full == 1'b0));
    endproperty

    a_rst_zero :
    assert property (rst_zero)
    else begin
        $display(
            "[Interface] reset = %d empty or full value error ! empty = %d, full =%d",
            rst, empty, full);
    end
endinterface
class transaction;
    logic            rst;
    rand logic       push;
    rand logic       pop;
    rand logic [7:0] push_data;
    logic      [7:0] pop_data;
    logic            empty;
    logic            full;

    function debug_log(string name);
        $display(
            "%t [%s] push: %d,pop: %d,push_data:%d,pop_data:%d,empty:%d,full:%d",
            $time, name, push, pop, push_data, pop_data, empty, full);
    endfunction

    // constraint push_only {
    //     push dist {
    //         0 :/ 0,
    //         1 :/ 10
    //     };
    //     pop dist {
    //         0 :/ 10,
    //         1 :/ 0
    //     };
    // }
    // constraint pop_only {
    //     push dist {
    //         0 :/ 10,
    //         1 :/ 0
    //     };
    //     pop dist {
    //         0 :/ 0,
    //         1 :/ 10
    //     };
    // }
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;
    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run(int run_cnt);
        repeat (run_cnt) begin
            tr = new;
            tr.randomize();
            tr.debug_log("GEN");
            gen2drv_mbox.put(tr);

            @(gen_next_evt);
        end
    endtask
endclass
class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual fifo_interface fifo_vif;
    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_vif = fifo_vif;
    endfunction
    task preset();
        fifo_vif.rst = 1;
        @(negedge fifo_vif.clk);
        @(negedge fifo_vif.clk);
        fifo_vif.rst = 0;
    endtask
    task run();
        forever begin
            @(posedge fifo_vif.clk);
            gen2drv_mbox.get(tr);
            tr.debug_log("DRV");
            #1;
            fifo_vif.push = tr.push;
            fifo_vif.pop = tr.pop;
            fifo_vif.push_data = tr.push_data;
        end
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual fifo_interface fifo_vif;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_vif = fifo_vif;
    endfunction

    task run();
        forever begin
            @(negedge fifo_vif.clk);
            tr           = new;
            tr.rst       = fifo_vif.rst;
            tr.push      = fifo_vif.push;
            tr.pop       = fifo_vif.pop;
            tr.push_data = fifo_vif.push_data;
            tr.pop_data  = fifo_vif.pop_data;
            tr.full      = fifo_vif.full;
            tr.empty     = fifo_vif.empty;
            mon2scb_mbox.put(tr);
            tr.debug_log("MON");
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_evt;
    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    logic [7:0] expected_q[$:3];
    logic [7:0] expected_pop_data;

    int pass_cnt, fail_cnt, total_cnt = 0;
    int
        push_only_pass,
        pop_only_pass,
        push_pop_pass,
        push_pop_only_push_pass,
        push_pop_only_pop_pass = 0;
    int
        push_only_fail,
        pop_only_fail,
        push_pop_fail,
        push_pop_only_push_fail,
        push_pop_only_pop_fail = 0;

    int full_pass, full_fail, empty_pass, empty_fail = 0;
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_log("SCB");
            if (!tr.rst) begin
                total_cnt++;
                if (tr.full === (expected_q.size() == 4)) begin
                    full_pass++;
                end else begin
                    full_fail++;
                    $display(
                        "[fail] full : expected = %0d, tr.full = %0d, q.size = %0d",
                        (expected_q.size() == 4), tr.full, expected_q.size());
                end
                if (tr.empty === (expected_q.size() == 0)) begin
                    empty_pass++;
                end else begin
                    empty_fail++;
                    $display(
                        "[fail] empty : expected = %0d, tr.empty = %0d, q.size = %0d",
                        (expected_q.size() == 0), tr.empty, expected_q.size());
                end
                if (tr.push & tr.pop) begin
                    //full 이라면 pop만
                    if (expected_q.size() == 4) begin
                        expected_pop_data = expected_q.pop_front();
                        if (expected_pop_data === tr.pop_data) begin
                            pass_cnt++;
                            push_pop_pass++;
                            push_pop_only_pop_pass++;
                            $display(
                                "[pass] [push,pop] expected_pop_data = %d, tr.pop_data = %d",
                                expected_pop_data, tr.pop_data);
                        end else begin
                            fail_cnt++;
                            push_pop_fail++;
                            push_pop_only_pop_pass++;
                            $display(
                                "[fail] [push,pop] expected_pop_data = %d, tr.pop_data = %d",
                                expected_pop_data, tr.pop_data);
                        end
                        //empty면 push만
                    end else if (expected_q.size() == 0) begin
                        expected_q.push_back(tr.push_data);
                        push_pop_pass++;
                        push_pop_only_push_pass++;
                    end else begin
                        expected_q.push_back(tr.push_data);
                        expected_pop_data = expected_q.pop_front();
                        if (expected_pop_data === tr.pop_data) begin
                            pass_cnt++;
                            push_pop_pass++;
                            pop_only_pass++;
                            $display(
                                "[pass] expected_pop_data = %d, tr.pop_data = %d",
                                expected_pop_data, tr.pop_data);
                        end else begin
                            fail_cnt++;
                            push_pop_fail++;
                            pop_only_fail++;
                            $display(
                                "[fail] expected_pop_data = %d, tr.pop_data = %d",
                                expected_pop_data, tr.pop_data);
                        end
                    end
                end else if (tr.push) begin
                    if (!(expected_q.size() == 4)) begin
                        expected_q.push_back(tr.push_data);
                        push_only_pass++;
                        pass_cnt++;
                    end
                end else if (tr.pop) begin
                    if (!(expected_q.size() == 0)) begin
                        expected_pop_data = expected_q.pop_front();
                        if (expected_pop_data === tr.pop_data) begin
                            pass_cnt++;
                            $display(
                                "[pass] expected_pop_data = %d, tr.pop_data = %d",
                                expected_pop_data, tr.pop_data);
                        end else begin
                            fail_cnt++;
                            $display(
                                "[fail] expected_pop_data = %d, tr.pop_data = %d",
                                expected_pop_data, tr.pop_data);
                        end
                    end
                end
            end
            ->gen_next_evt;
        end

        // forever begin
        //     mon2scb_mbox.get(tr);
        //     tr.debug_log("SCB");
        //     total_cnt++;
        //     if (!tr.rst) begin
        //         if (!tr.full & tr.push) begin
        //             expected_q.push_back(tr.push_data);
        //         end
        //         if (!tr.empty & tr.pop) begin
        //             expected_pop_data = expected_q.pop_front();
        //             if (expected_pop_data === tr.pop_data) begin
        //                 pass_cnt++;
        //                 $display(
        //                     "[pass] expected_pop_data = %d, tr.pop_data = %d",
        //                     expected_pop_data, tr.pop_data);
        //             end else begin
        //                 fail_cnt++;
        //                 $display(
        //                     "[fail] expected_pop_data = %d, tr.pop_data = %d",
        //                     expected_pop_data, tr.pop_data);
        //             end
        //         end
        //     end
        //     ->gen_next_evt;
        // end
    endtask

    task report();
        $display("================================================");
        $display("            FIFO VERIFICATION REPORT");
        $display("================================================");
        $display("| total transaction (no rst)  : %5d          |", total_cnt);
        $display("| total pass                  : %5d          |", pass_cnt);
        $display("| total fail                  : %5d          |", fail_cnt);
        $display("------------------------------------------------");
        $display("| [push & pop]                                 |");
        $display("|   pass                      : %5d          |",
                 push_pop_pass);
        $display("|   - full  -> pop only       : %5d          |",
                 push_pop_only_pop_pass);
        $display("|   - empty -> push only      : %5d          |",
                 push_pop_only_push_pass);
        $display("|   fail                      : %5d          |",
                 push_pop_fail);
        $display("------------------------------------------------");
        $display("| [push only]                                  |");
        $display("|   push done                 : %5d          |",
                 push_only_pass);
        $display("------------------------------------------------");
        $display("| [pop only]                                   |");
        $display("|   pass                      : %5d          |",
                 pop_only_pass);
        $display("|   fail                      : %5d          |",
                 pop_only_fail);
        $display("------------------------------------------------");
        $display("| [full/empty check]                           |");
        $display("|   full  pass                : %5d          |", full_pass);
        $display("|   full  fail                : %5d          |", full_fail);
        $display("|   empty pass                : %5d          |", empty_pass);
        $display("|   empty fail                : %5d          |", empty_fail);
        $display("================================================");

    endtask
endclass

class environment;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_evt;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    virtual fifo_interface fifo_vif;
    function new(virtual fifo_interface fifo_vif);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, fifo_vif);
        mon = new(mon2scb_mbox, fifo_vif);
        scb = new(mon2scb_mbox, gen_next_evt);
    endfunction

    task run(int cnt);
        drv.preset();
        fork
            gen.run(cnt);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        scb.report();
    endtask

endclass
module tb_fifo_sv ();
    logic clk = 0;
    fifo_interface fifo_if (clk);
    environment env;

    fifo_sv dut (
        .clk(clk),
        .rst(fifo_if.rst),
        .push(fifo_if.push),
        .pop(fifo_if.pop),
        .push_data(fifo_if.push_data),
        .pop_data(fifo_if.pop_data),
        .empty(fifo_if.empty),
        .full(fifo_if.full)
    );

    always #5 clk = ~clk;

    initial begin
        env = new(fifo_if);
        env.run(90);
        $finish;
    end
endmodule
