`include "uvm_macros.svh"

import uvm_pkg::*;

// interface, virtual interface
interface base_interface(input clk);
	logic [7:0] wdata;	// drive		t_data
	logic [7:0] rdata;	// monitor	rdata
	logic [7:0] addr;		// drive		t_addr
	logic we;						// drive		if( kind==WRITE) we = 1
endinterface


// UVM_Transaction
typedef enum {READ, WRITE} kind_e;
class base_item extends uvm_sequence_item;
	rand bit [7:0] t_data;
	rand bit [7:0] t_addr;
	rand kind_e		 kind;
	constraint c_addr {
		t_addr inside { [0:63] };
	}

	// item registry to uvm_object
	`uvm_object_utils_begin(base_item)
		`uvm_field_int	(t_data, UVM_ALL_ON)
		`uvm_field_int	(t_addr, UVM_ALL_ON)
		`uvm_field_enum	(kind_e, kind, UVM_ALL_ON)
	`uvm_object_utils_end

	function new(string name = "base_item");
		super.new(name);
	endfunction


	function void debug_print(string name);
			`uvm_info(name ,$sformatf(" t_data = %d, t_addr = %d, kind = %d",
																					t_data,t_addr,kind ),UVM_MEDIUM)
	endfunction

endclass

// UVM_Sequence
class base_seq extends uvm_sequence #(base_item);
	`uvm_object_utils(base_seq)
	base_item	seq_item;

	function new(string name = "base_seq");
		super.new(name);
	endfunction

	task body();
		repeat(10) begin
			seq_item = base_item::type_id::create("base_seq_item");
			`uvm_info("base_seq"," body - 1 start seq item", UVM_LOW)
			start_item(seq_item);		// to wait until request from driver/sequencer
			if (!seq_item.randomize() ) begin
				`uvm_fatal("base_seq", " fail seq_item randomized ")
			end 
			// debug seq item
			seq_item.debug_print("base_seq");

			finish_item(seq_item);
		end
	endtask

endclass

// UVM_Component
// ENV, AGENT, DRIVER, MONITOR, SCOREBOARD, COVERAGE
// parameterize class driver
class base_driver extends uvm_driver #(base_item);
	`uvm_component_utils(base_driver)
	base_item	seq_item;
	// virtual interface handle
	virtual base_interface base_vif;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		// virtual interface get
		if(!uvm_config_db #(virtual base_interface)::get(this,"","base_vif",base_vif) ) begin
			`uvm_fatal(get_name()," unable to access base interface")
		end
		`uvm_info("base_driver"," build phase - driver", UVM_LOW)
	endfunction


	task run_phase(uvm_phase phase);
			forever begin
				seq_item_port.get_next_item(seq_item);
				@(negedge base_vif.clk);
				// to drive to virtual interface
				base_vif.addr = seq_item.t_addr;
				base_vif.wdata = seq_item.t_data;
				if(seq_item.kind == WRITE) begin
					base_vif.we = 1;
				end else begin
					base_vif.we = 0;
				end
				`uvm_info("base_driver"," run phase - driver", UVM_LOW)
				seq_item.debug_print("base_driver");
				seq_item_port.item_done();
			end
	endtask

endclass

// normal class 
class base_monitor extends uvm_monitor;
	`uvm_component_utils(base_monitor)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		`uvm_info("base_monitor"," build phase - monitor", UVM_LOW)
	endfunction

endclass

class base_agent extends uvm_agent;
	`uvm_component_utils(base_agent)

	base_driver		drv;
	base_monitor	mon;
	uvm_sequencer	#(base_item) base_sqr;	// sequencer


	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("base_agent"," build phase - agent", UVM_LOW)
		drv = base_driver::type_id::create("drv", this);	// (name,parent)
		mon = base_monitor::type_id::create("mon", this);	// (name,parent)
		// to use uvm_sequencer
		base_sqr = uvm_sequencer#(base_item)::type_id::create("sqr", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		drv.seq_item_port.connect(base_sqr.seq_item_export);
	endfunction


endclass

class base_env	extends uvm_env;
	`uvm_component_utils(base_env)

	base_agent agt;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("base_env"," build phase - env", UVM_LOW)	
		agt = base_agent::type_id::create("agt", this);
	endfunction
endclass


class uvm_test_base extends uvm_test;
	`uvm_component_utils(uvm_test_base)
	base_seq	seq;	// sequence	
	base_env	env;	// environemt

	function new (string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	// configuration phase
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("base_test"," build phase - test", UVM_LOW)	
		seq = base_seq::type_id::create("seq",this);
		env = base_env::type_id::create("env", this);
	endfunction
	// exceute phase
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		`uvm_info("uvm_test_base","hello_uvm", UVM_LOW)
		// sequence -> sequencer
		seq.start(env.agt.base_sqr);
		#100;
		`uvm_info("uvm_test_base","** end of uvm test_base **", UVM_LOW)
		phase.drop_objection(this);
		#10;
	endtask
	// display : hirerachy structure 
	function void end_of_elaboration_phase(uvm_phase phase);
		uvm_root::get().print_topology();
	endfunction

endclass

module tb_top;
	logic clk = 0;
	base_interface	base_if(clk);
	sram dut(
		.clk		(clk),
		.addr		(base_if.addr),
		.wdata	(base_if.wdata),
		.we			(base_if.we),
		.rdata	(base_if.rdata)
	);

	always #5 clk = ~clk;

	initial begin
		$fsdbDumpfile("wave.fsdb");
		$fsdbDumpvars(0);
	end

	initial begin
		// registry uvm db
		uvm_config_db #(virtual base_interface)::set(null, "*", "base_vif", base_if);
		run_test("uvm_test_base");
		$finish;
	end

endmodule
