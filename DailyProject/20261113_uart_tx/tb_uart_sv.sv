`timescale 1ns / 1ps
interface uart_interface (
    input clk
);
    logic        rst;
    logic        start;
    logic [ 7:0] tx_data;
    logic        tx;
    logic        tx_busy;
    // logic [31:0] interval;
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
    // constraint coverage_tx_data {
    //     tx_data dist {
    //         8'haa := 10,
    //         8'h55 := 10,
    //         [8'h00 : 8'hff] :/ 80
    //     };
    // }

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
            @(negedge uart_vif.clk);
            busy_check_count = 0;
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");

            //busy끝나길 무한 대기
            while (uart_vif.tx_busy) begin
                @(negedge uart_vif.clk);
                busy_check_count++;
                if (busy_check_count > 10419 * 10) begin
                    $display("tx_busy high was too long.........!");
                    break;
                end
            end

            if (!uart_vif.tx_busy) begin
                //interval
                repeat (tr.interval+1) @(negedge uart_vif.clk);
                uart_vif.rst      = tr.rst;
                uart_vif.start    = 1;
                // tr.start         = 1;
                uart_vif.tx_data  = tr.tx_data;
                // uart_vif.interval = tr.interval;
                $display("%t drv -> vif", $time);
                @(negedge uart_vif.clk);
                uart_vif.start   = 0;
                uart_vif.tx_data = 8'hxx;
                // tr.start         = 0;
            end else begin
                uart_vif.start = 0;
            end
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
    bit [3:0] counter = 0;
    logic [7:0] ouput_tx;
    // int unsigned start_time, 
    int unsigned end_time = 0;
    int unsigned startBit_start_pass, startBit_end_pass = 0;
    int unsigned startBit_start_fail, startBit_end_fail = 0;
    int frame_time_pass, frame_time_fail = 0;

    time frame_start_time;
    time start_time, c_time;

    task uart_receive(output logic [7:0] receive_data);
        $display("***%t uart_vif.tx: %d", $time, uart_vif.tx);
        @(!uart_vif.tx);
        $display("***%t uart_vif.tx: %d", $time, uart_vif.tx);
        //to check of start bit error
        start_time = $time;
        frame_start_time = start_time;
        c_time = $time;
        //check start
        while (uart_vif.tx == 0 & ((c_time - start_time) <= BAUD_TIME)) begin
            @(posedge uart_vif.clk);
            c_time = $time;
        end
        if ((c_time - start_time) >= (BAUD_TIME - BAUD_TIME / 16)) begin
            tr_out.start_bit_error = 0;
        end else begin
            tr_out.start_bit_error = 1;
        end

        $display("%t :[start bit time] c_time - start_time = %d", $time,
                 (c_time - start_time));
        //checkstart bit
        for (int i = 0; i < 8; i++) begin
            #(BAUD_TIME / 2);
            receive_data[i] = uart_vif.tx;
            #(BAUD_TIME / 2);
        end
        //tx 0일까봐 대기
        start_time = $time;
        c_time = start_time;

        while ((!uart_vif.tx) && ((c_time - start_time) <= BAUD_TIME / 2)) begin
            @(posedge uart_vif.clk);
            c_time = $time;
        end

        if ((c_time - start_time) >= BAUD_TIME / 2) begin
            tr_out.stop_bit_error = 1;
        end else begin
            //stop bit check
            start_time = $time;
            c_time = start_time;
            //stop bit begin
            while ((uart_vif.tx == 1) && (uart_vif.tx_busy)&&((c_time - start_time) <= BAUD_TIME) ) begin
                @(posedge uart_vif.clk);
                c_time = $time;
            end
            if ((c_time - start_time) >= (BAUD_TIME - BAUD_TIME / 16)) begin
                tr_out.stop_bit_error = 0;
            end else begin
                tr_out.stop_bit_error = 1;
            end
            $display("%t :[stop bit time] c_time - start_time = %d", $time,
                     (c_time - start_time));
        end
        //frame time check
        c_time = $time;
        if (((
            c_time - frame_start_time
            ) <= (FRAME_TIME + (BAUD_TIME / 2))) && ((
            c_time - frame_start_time
            ) >= (FRAME_TIME - (BAUD_TIME / 2)))) begin
            tr_out.frame_time_error = 0;
        end else begin
            tr_out.frame_time_error = 1;
        end
        $display("%t :[frame time] c_time - start_time = %d", $time,
                 (c_time - start_time));






        // start_time = $time;
        // c_time = start_time;
        // #(BAUD_TIME / 2);
        // //stop
        // #(BAUD_TIME / 2);



        // // #(BAUD_TIME);
        // //stop bit check
        // // #(BAUD_TIME / 2);
        // @(negedge uart_vif.tx_busy);
        // $display("%t busy down", $time);
        // end_time = $time;
        // dge uart_vif.clk);
        // @(negedge uart_vif.tx);

        // start_time = $time;
        // #((BAUD_TIME ) / 16);
        // if (uart_vif.tx == 0) startBit_start_pass++;
        // else startBit_start_fail++;
        // $display("uart_vif.tx: %d",uart_vif.tx);
        // // #(BAUD_TIME / 2);
        // #((BAUD_TIME * 14) / 16);
        // if (uart_vif.tx == 0) startBit_end_pass++;
        // else startBit_end_fail++;
        // // $display("uart_vif.tx: %d",uart_vif.tx);
        // #((BAUD_TIME * 9) / 16);
        // //checkstart bit
        // for (int i = 0; i < 8; i++) begin
        //     receive_data[i] = uart_vif.tx;
        //     #(BAUD_TIME);
        // end
        // // #(BAUD_TIME);
        // //stop bit check
        // // #(BAUD_TIME / 2);
        // @(negedge uart_vif.tx_busy);
        // $display("%t busy down", $time);
        // end_time = $time;

    endtask
    time start_interval, c_time_interval = 0;
    int interval_cnt = 0;
    task run();
        forever begin
            //1.check start ==1
            // @(posedge uart_vif.clk);
            $display("%t MON_start", $time);
            while (!uart_vif.start) begin
                // $display("%t MON_while", $time);
                @(posedge uart_vif.clk);
                #1;
            end
            c_time_interval = $time;
            $display("%t MON_while END", $time);
            //2. mon2scb_in_mbox put
            tr_in = new;
            tr_in.tx_data = uart_vif.tx_data;
            tr_in.interval = (c_time_interval -start_interval) / 10;
            mon2scb_in_mbox.put(tr_in);
            tr_in.debug_print("MON-IN");

            //3. baud_time *10,mon2scb_out_mbox put
            //receive task
            tr_out = new;
            uart_receive(tr_out.tx_data);
            tr_out.rst      = uart_vif.rst;
            tr_out.tx_busy  = uart_vif.tx_busy;
            tr_out.tx       = uart_vif.tx;
            start_interval  = $time;
            // tr_out.interval = ;
            mon2scb_out_mbox.put(tr_out);
            tr_out.debug_print("MON-OUT");
            // if ((BAUD_TIME*10-(BAUD_TIME / 16))<=(end_time - start_time) <= (BAUD_TIME*10+(BAUD_TIME / 16))) begin
            //     frame_time_pass++;
            // end else frame_time_fail++;
            // $display("frame_time_pass = %d, frame_time_fail = '%d",
            //          frame_time_pass, frame_time_fail);
            // $display("startBit_start_pass = %d, startBit_start_fail = %d",
            //          startBit_start_pass, startBit_start_fail);
            // $display("startBit_end_pass = %d, startBit_end_fail = %d",
            //          startBit_end_pass, startBit_end_fail);
            // $display("startBit_pass = %d, startBit_fail = %d",
            //          startBit_start_pass & startBit_end_pass,
            //          startBit_start_fail & startBit_end_fail);

            // #1;
            // if (uart_vif.start & !uart_vif.tx_busy) begin
            //     tr_in = new;
            //     tr_in.tx_data = uart_vif.tx_data;
            //     mon2scb_in_mbox.put(tr_in);
            // end
            // if (uart_vif.tx_busy) begin
            //     //tx(start+data8bit+stop)
            //     if (counter == 0) begin
            //         //
            //         #(BAUD_TIME / 2);
            //         if (uart_vif.tx == 0) counter++;
            //         tr_out = new;
            //     end else if (counter < 9) begin
            //         #(BAUD_TIME);
            //         ouput_tx = {uart_vif.tx, ouput_tx[7:1]};
            //         counter++;
            //     end else if (counter == 9) begin
            //         if (uart_vif.tx == 1) begin
            //             counter = 0;
            //             tr_out.tx_data = ouput_tx;
            //             mon2scb_out_mbox.put(tr_out);
            //         end
            //     end
            // end
        end
    endtask
endclass

class scoreboard;
    transaction tr_in, tr_out;
    mailbox #(transaction) mon2scb_in_mbox, mon2scb_out_mbox;
    event gen_next_evt;

    //coverage declaration
    covergroup cg_tx;
        option.per_instance = 1;
        // cp_interval_zero: coverpoint tr_out.interval {bins zero = {32'b0};}
        cp_interval: coverpoint tr_in.interval {
            bins interval_coner = {0}; bins interval_time[] = {[1 : 1041]};
        }
        cp_txdata: coverpoint tr_in.tx_data {
            bins edge_aa = {8'haa};
            bins edge_55 = {8'h55};
            bins data[] = {[0 : 255]};
        }
    endgroup
    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox, event gen_next_evt);
        this.mon2scb_in_mbox  = mon2scb_in_mbox;
        this.mon2scb_out_mbox = mon2scb_out_mbox;
        this.gen_next_evt     = gen_next_evt;
        cg_tx                 = new;
    endfunction

    int tx_data_pass_cnt, tx_data_fail_cnt, total_cnt = 0;
    int tx_start_bit_pass_cnt, tx_start_bit_fail_cnt = 0;
    int tx_stop_bit_pass_cnt, tx_stop_bit_fail_cnt = 0;
    int tx_frame_time_pass_cnt, tx_frame_time_fail_cnt = 0;
    task run();
        forever begin
            mon2scb_in_mbox.get(tr_in);
            tr_in.debug_print("SCB-IN");
            mon2scb_out_mbox.get(tr_out);
            tr_out.debug_print("SCB-OUT");
            total_cnt++;
            //tx start bit pass / fail
            if (!tr_out.start_bit_error) begin
                tx_start_bit_pass_cnt++;
                $display("tx start bit pass !!!");
            end else begin
                tx_start_bit_fail_cnt++;
                $display("tx start bit fail !!!");
            end
            if (!tr_out.stop_bit_error) begin
                tx_stop_bit_pass_cnt++;
                $display("tx stop bit pass !!!");
            end else begin
                tx_stop_bit_fail_cnt++;
                $display("tx stop bit fail !!!");
            end
            if (!tr_out.frame_time_error) begin
                tx_frame_time_pass_cnt++;
                $display("tx stop bit pass !!!");
            end else begin
                tx_frame_time_fail_cnt++;
                $display("tx stop bit fail !!!");
            end
            //tx data pass/fail
            if (tr_in.tx_data === tr_out.tx_data) begin
                tx_data_pass_cnt++;
                $display("tx_data pass!! tr_in: %d,tr_out: %d", tr_in.tx_data,
                         tr_out.tx_data);
            end else begin
                tx_data_fail_cnt++;
                $display("tx_data fail!! tr_in: %d,tr_out: %d", tr_in.tx_data,
                         tr_out.tx_data);
            end
            cg_tx.sample();
            ->gen_next_evt;
        end
    endtask

    task report();
        $display("================================================");
        $display("          UART TX VERIFICATION REPORT");
        $display("================================================");
        $display("| total frame                 : %5d          |", total_cnt);
        $display("------------------------------------------------");
        $display("| [start bit]                                  |");
        $display("|   pass                      : %5d          |",
                 tx_start_bit_pass_cnt);
        $display("|   fail                      : %5d          |",
                 tx_start_bit_fail_cnt);
        $display("------------------------------------------------");
        $display("| [data]                                       |");
        $display("|   pass                      : %5d          |",
                 tx_data_pass_cnt);
        $display("|   fail                      : %5d          |",
                 tx_data_fail_cnt);
        $display("------------------------------------------------");
        $display("| [stop bit]                                   |");
        $display("|   pass                      : %5d          |",
                 tx_stop_bit_pass_cnt);
        $display("|   fail                      : %5d          |",
                 tx_stop_bit_fail_cnt);
        $display("------------------------------------------------");
        $display("| [frame time]                                 |");
        $display("|   pass                      : %5d          |",
                 tx_frame_time_pass_cnt);
        $display("|   fail                      : %5d          |",
                 tx_frame_time_fail_cnt);
        $display("------------------------------------------------");
        $display("| [coverage]                                   |");
        $display("|   interval zero             : %6.2f %%       |",
                 cg_tx.cp_interval.get_coverage());
        $display("|   tx_data                   : %6.2f %%       |",
                 cg_tx.cp_txdata.get_coverage());
        $display("================================================");

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
