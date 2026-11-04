`timescale 1ns / 1ps

class transaction;
    
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand bit mode;

    logic [7:0] s;
    logic c;

    function debug_print(string name);
        $display("%t : [%s] a = %d,b = %d,mode = %d, s = %d, c = %d", $time,
                 name, a, b, mode, s, c);

    endfunction
endclass 

interface adder_interface ();
    logic [7:0] a;
    logic [7:0] b;
    logic       mode;
    logic [7:0] s;
    logic       c;
endinterface

class generator;
    transaction tr;  

    mailbox #(transaction) gen2drv_mbox;
    
    function new(mailbox#(transaction) gen2drv_mbox_a);
        
        gen2drv_mbox = gen2drv_mbox_a;
    endfunction

    task run();
        repeat (256) begin
            tr = new;  
            
            tr.randomize();
            tr.debug_print("GEN");
            gen2drv_mbox.put(tr);
        end
    endtask
endclass


class driver;
    transaction tr; 
    mailbox #(transaction) gen2drv_mbox; 
    virtual adder_interface adder_if_v;
    function new(mailbox#(transaction) gen2drv_mbox_a,
                 virtual adder_interface adder_if_v_a);
        gen2drv_mbox = gen2drv_mbox_a;
        adder_if_v   = adder_if_v_a; 
    endfunction

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            
            adder_if_v.a = tr.a;
            adder_if_v.b = tr.b;
            adder_if_v.mode = tr.mode; 
            #10;
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    mailbox #(transaction) gen2drv_mbox;

    function new(virtual adder_interface adder_if_v);
        gen2drv_mbox = new;
        gen = new(gen2drv_mbox);
        drv = new(gen2drv_mbox, adder_if_v);
    endfunction

    task run();
        forever begin
            gen.run();
            drv.run();
        end
    endtask
endclass


module tb_adder_sv ();

    adder_interface adder_if (); 

    environment env;
    adder dut (
        .a   (adder_if.a),
        .b   (adder_if.b),
        .mode(adder_if.mode),
        .s   (adder_if.s),
        .c   (adder_if.c)
    );

    initial begin
        env = new(adder_if);
        env.run();
        $finish;
    end

endmodule
