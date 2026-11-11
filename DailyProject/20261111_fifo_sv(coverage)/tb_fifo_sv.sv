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

    //by 수영
    // property rst_zero;
    //     // ->: 현재 사이클 =>: 다음 사이클 
    //     @(posedge clk) rst |-> ((empty === 1'b1) & (full === 1'b0)); //case등가, include x,z
    // endproperty

    // a_rst_zero :
    // assert property (rst_zero)
    // else begin
    //     $display(
    //         "[Interface] reset = %d empty or full value error ! empty = %d, full =%d",
    //         rst, empty, full);
    // end

    property p_rst_full;
        // ->: 현재 사이클 =>: 다음 사이클 
        @(posedge clk) rst |-> (full === 1'b0);  //case등가, include x,z
    endproperty
    property p_rst_empty;
        // ->: 현재 사이클 =>: 다음 사이클 
        @(posedge clk) rst |-> (empty === 1'b1);  //case등가, include x,z
    endproperty

    a_rst_full :
    assert property (p_rst_full)
    else begin
        $display("%t [Interface assert] reset = %d full value error ! full =%d",
                 $time, rst, full);
    end
    a_rst_empty :
    assert property (p_rst_empty)
    else begin
        $display(
            "%t [Interface assert] reset = %d empty value error ! empty =%d",
            $time, rst, empty);
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
    int              scenario;

    function debug_log(string name);
        $display(
            "%t [%s] push: %d,pop: %d,push_data:%d,pop_data:%d,empty:%d,full:%d",
            $time, name, push, pop, push_data, pop_data, empty, full);
    endfunction



    constraint test_scenario {
        if (scenario == 1) {  //push only
            push dist {
                0 :/ 0,
                1 :/ 10
            };
            pop dist {
                0 :/ 10,
                1 :/ 0
            };
        } else
        if (scenario == 2) {  //pop only
            push dist {
                0 :/ 10,
                1 :/ 0
            };
            pop dist {
                0 :/ 0,
                1 :/ 10
            };
        }
    }
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
        int push_only_count, pop_only_count = 10;
        repeat (push_only_count) begin
            tr = new;
            tr.scenario = 1;
            tr.randomize();
            tr.debug_log("GEN");
            gen2drv_mbox.put(tr);

            @(gen_next_evt);
        end
        repeat (pop_only_count) begin
            tr = new;
            tr.scenario = 2;
            tr.randomize();
            tr.debug_log("GEN");
            gen2drv_mbox.put(tr);

            @(gen_next_evt);
        end
        repeat (run_cnt) begin
            tr = new;
            tr.scenario = 3;
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
        fifo_vif.rst       = 1;
        fifo_vif.push      = 0;
        fifo_vif.push      = 0;
        fifo_vif.push_data = 0;
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
    logic [7:0] expected_q[$:3];
    logic [7:0] expected_pop_data;

    //coverage
    covergroup cg_fifo;
        option.per_instance = 1;
        //fifo push data
        cp_push_data: coverpoint tr.push_data iff (tr.push) {
            bins full[] = {[0 : 255]};
        }

        //fifo push,pop : op
        cp_push_pop: coverpoint {
            tr.push, tr.pop
        } {
            bins idle = {2'b00};
            bins push_only = {2'b10};
            bins pop_only = {2'b01};
            bins push_pop = {2'b11};
        }
        //fifo full,empty : state
        cp_full_empty: coverpoint {
            tr.full, tr.empty
        } {
            bins normal = {2'b00}; bins full = {2'b10}; bins empty = {2'b01};
        // bins error_full_empty = {2'b11}; //never have this case/
        }
        cp_q_size: coverpoint q_size {bins size[] = {[0 : 4]};}


        cx_op_st: cross cp_push_pop, cp_full_empty;
        cx_op_fifo_depth: cross cp_push_pop, cp_q_size;
    endgroup

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_evt = gen_next_evt;
        this.cg_fifo = new;
    endfunction



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
    int q_size=0;

    //수업
    // bit expect_full = 0, expect_empty = 1;
    // int full_pass_cnt, full_fail_cnt, empty_pass_cnt, empty_fail_cnt = 0;
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_log("SCB");
            if (!tr.rst) begin
                total_cnt++;

                //by 수업
                //      forever begin
                // mon2scb_mbox.get(tr);
                // tr.debug_log("SCB");
                // total_cnt++;
                // if (!tr.rst) begin
                //     if (expected_q.size() == 4) begin
                //         expect_full = 1;
                //     end else expect_full = 0;
                //     if (expected_q.size() == 0) begin
                //         expect_empty = 1;
                //     end else expect_empty = 0;



                //     // full,empty pass/fail
                //     if (expect_full == tr.full) begin
                //         $display("pass : fifo full signal");
                //         full_pass_cnt++;
                //     end else begin
                //         $display("fail: fifo full signal");
                //         full_fail_cnt++;
                //     end

                //     if(expect_empty == tr.empty)begin
                //         $display("pass : fifo empty signal");
                //         empty_pass_cnt++;
                //     end else begin
                //         $display("fail: fifo empty signal");
                //         fual_fail_cnt++;
                // end

                // if (!expect_full & tr.push) begin
                //                     expect_fifo.push_back(tr.push_data);
                //                 end





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










                //by수영
                q_size = expected_q.size();
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
                //coverage 1 update
                cg_fifo.sample();
            end
            ->gen_next_evt;
        end


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
        $display("------------------------------------------------");
        $display("| [coverage]                                   |");
        $display("|   push_data                 : %4.2f %%        |",
                 cg_fifo.cp_push_data.get_coverage());
        $display("|   push,pop op               : %4.2f %%       |",
                 cg_fifo.cp_push_pop.get_coverage());
        $display("|   full,empty st             : %4.2f %%       |",
                 cg_fifo.cp_full_empty.get_coverage());
        $display("|   cross op,st               : %4.2f %%       |",
                 cg_fifo.cx_op_st.get_coverage());
        $display("|   q size                    : %4.2f %%       |",
                 cg_fifo.cp_q_size.get_coverage());
        $display("|   cx_op_fifo_depth          : %4.2f %%       |",
            cg_fifo.cx_op_fifo_depth.get_coverage());
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
        env.run(10000);
        $finish;
    end
endmodule
