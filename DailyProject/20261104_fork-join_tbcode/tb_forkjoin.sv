`timescale 1ns / 1ps

module tb_forkjoin ();

    // initial begin
    //      #1 $display("%t : start fork - join",$time);
    //      fork
    //         #10 A_thread();
    //         #20 B_thread();
    //         #15 C_thread();
    //      join_any
    //      #10 $display("%t : end fork -join_any",$time);
    // end

    // initial begin
    //      #1 $display("%t : start fork - join",$time);
    //      fork
    //         #10 A_thread();
    //         #20 B_thread();
    //         #15 C_thread();
    //      join_none
    //      #10 $display("%t : end fork -join_none",$time);
    // end

    // initial begin
    //      #1 $display("%t : start fork - join",$time);
    //      fork
    //         #10 A_thread();
    //         #20 B_thread();
    //         #15 C_thread();
    //      join
    //      #10 $display("%t : end fork -join",$time);
    // end

    // initial begin
    //     #1 $display("%t : start fork - join", $time);
    //     fork
    //         #10 A_thread();

    //         fork
    //             #20 B_thread();
    //             #50 B_thread();
    //         join
    //         #30 C_thread();
    //     join_any
    //     #10 $display("%t : end fork -join", $time);
    // end

    // initial begin
    //     #1 $display("%t : start fork - join", $time);
    //     fork
    //         #10 A_thread();

    //         fork
    //             #3 B_thread();
    //             #5 B_thread();
    //         join
    //         #30 C_thread();
    //     join_any
    //     #10 $display("%t : end fork -join", $time);
    // end

    initial begin
        #1 $display("%t : start fork - join", $time);
        fork
            A_thread();
            B_thread();
            C_thread();
        join_any
        #10 $display("%t : end fork -join", $time);
        disable fork;
        $stop;
    end


    // task A_thread();
    //     $display("%t : A thread", $time);
    // endtask
    // task B_thread();
    //     $display("%t : B thread", $time);
    // endtask
    // task C_thread();
    //     $display("%t : C thread", $time);
    // endtask

    task A_thread();
        repeat (5) $display("%t : A thread", $time);
    endtask
    task B_thread();
        forever begin
            $display("%t : B thread", $time);
            #5;
        end
    endtask
    task C_thread();
        forever begin
            $display("%t : C thread", $time);
            #10;
        end
    endtask

endmodule
