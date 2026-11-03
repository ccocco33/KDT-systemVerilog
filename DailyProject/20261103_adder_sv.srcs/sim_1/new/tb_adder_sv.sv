`timescale 1ns / 1ps

// class transaction;  //class 로 만들어서 동적 할당을 함
//     //drive variable
//     //rand : randomize()시 rand key word 있는 변수만 random 값 생성
//     rand bit [7:0] a;
//     rand bit [7:0] b;
//     rand bit mode;
//     //monitor variable
//     logic [7:0] s;
//     logic c;
// endclass  // vector,stimulus 생성하는 객체

// class generator;
//     transaction tr;  //handle
//     virtual adder_interface adder_if_v;
//     function new(
//         virtual adder_interface adder_if_v_a
//     );  //generator 객체가 동적생성 될때 이걸 실행해라
//         adder_if_v = adder_if_v_a;  //virtual connection
//         tr = new;  // new 동적 할당 명령어 | 객체를 실제로 메모리에 생성하고 tr에 연결
//     endfunction

//     task run();
//         repeat (10) begin
//             //to generate for randomize stimulus by tr
//             tr.randomize();  // class 기본 제공 function
//             //drive
//             adder_if_v.a = tr.a;
//             adder_if_v.b = tr.b;
//             adder_if_v.mode = tr.mode; // mode를 0만 넣고싶으면 여기서 0 넣음
//             #10;
//         end
//     endtask
// endclass

// // interface adder_interface (
// //     input logic [7:0] a,
// //     input logic [7:0] b,
// //     input logic       mode,
// //     output logic [7:0] s,
// //     output logic       c
// //     );
// // endinterface

// interface adder_interface ();
//     logic [7:0] a;
//     logic [7:0] b;
//     logic       mode;
//     logic [7:0] s;
//     logic       c;
// endinterface

// module tb_adder_sv ();

//     // reg [7:0] a, b;
//     // reg        mode;
//     // wire [7:0] s;
//     // wire       c;

//     // logic [7:0] a, b;
//     // logic       mode;
//     // logic [7:0] s;
//     // logic       c;

//     adder_interface adder_if ();  //interface instance함
//     generator gen; 

//     // assign adder_if.a = a;
//     // assign adder_if.b = b;
//     // assign adder_if.mode = mode;
//     // assign adder_if.s = s; //단순 연결이라 이것도 허용
//     // assign adder_if.c =c;
//     adder dut (
//         .a   (adder_if.a),
//         .b   (adder_if.b),
//         .mode(adder_if.mode),
//         .s   (adder_if.s),
//         .c   (adder_if.c)
//         // .*  //포트이름과 변수이름이 같으면 자동 연결
//     );
//     initial begin
//         gen = new(adder_if);
//         gen.run();
//         $finish;
//     end
// endmodule

//________________________________________________________________________________________

class transaction;  //class 로 만들어서 동적 할당을 함
    //drive variable
    //rand : randomize()시 rand key word 있는 변수만 random 값 생성
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand bit mode;
    //monitor variable
    logic [7:0] s;
    logic c;

    function debug_print(string name);
        $display("%t : [%s] a = %d,b = %d,mode = %d, s = %d, c = %d", $time,
                 name, a, b, mode, s, c);

    endfunction
endclass  // vector,stimulus 생성하는 객체
interface adder_interface ();
    logic [7:0] a;
    logic [7:0] b;
    logic       mode;
    logic [7:0] s;
    logic       c;
endinterface

class generator;
    transaction tr;  //handle

    mailbox #(transaction) gen2drv_mbox;
    //generator 객체가 동적생성 될때 이걸 실행해라
    function new(mailbox#(transaction) gen2drv_mbox_a);
        //virtual mailbox #(tr..)... 이렇게 써도됨
        gen2drv_mbox = gen2drv_mbox_a;
    endfunction

    task run();
        repeat (256) begin
            tr = new;  // new 동적 할당 명령어 | 객체를 실제로 메모리에 생성하고 tr에 연결
            //to generate for randomize stimulus by tr
            tr.randomize();  // class 기본 제공 function
            tr.debug_print("GEN");
            gen2drv_mbox.put(tr);
        end
    endtask
endclass


class driver;
    transaction tr;  //handle
    mailbox #(transaction) gen2drv_mbox;  // 위에와 이름만 같을뿐
    virtual adder_interface adder_if_v;
    function new(mailbox#(transaction) gen2drv_mbox_a,
                 virtual adder_interface adder_if_v_a);
        gen2drv_mbox = gen2drv_mbox_a;
        adder_if_v   = adder_if_v_a;  //virtual connection
    endfunction

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            //drive
            adder_if_v.a = tr.a;
            adder_if_v.b = tr.b;
            adder_if_v.mode = tr.mode; // mode를 0만 넣고싶으면 여기서 0 넣음
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

    adder_interface adder_if ();  //interface instance함

    environment env;
    adder dut (
        .a   (adder_if.a),
        .b   (adder_if.b),
        .mode(adder_if.mode),
        .s   (adder_if.s),
        .c   (adder_if.c)
        // .*  //포트이름과 변수이름이 같으면 자동 연결
    );

    initial begin
        env = new(adder_if);
        env.run();
        $finish;
    end

endmodule

