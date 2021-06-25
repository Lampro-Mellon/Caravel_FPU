// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`include "compare.sv"
`include "add_sub.sv"
`include "fpu_lib.sv"
`include "float_to_int.sv"
`include "f_class.sv"
`include "divider.sv"
`include "min_max.sv"
`include "multiplier.sv"
`include "sign_inject.sv"
`include "int_to_float.sv"
`include "fused_mul.sv"
`include "sqrt_fpu.sv"
`include "registers.sv"

module fpu_top
(
  input  wire            clk,                    
  input  wire            rst_l,                  // active low reset       
  
  input  wire            wb_valid,               // valid signal from wb
  input  wire [31:0]     rdwraddr,               // read/write address from wb
  input  wire [31:0]     wrdata,                 // write data received from wb

  input  wire [31:0]     la_write,               // wire analyzer write enable
  input  wire [31:0]     la_data,                // wire analyzer write data
  input  wire [31:0]     la_addr,                // wire analyzer address
//outputs
  output wire            illegal_op,
  output wire            ack,

  output wire [31:0]     rddata,                 // read  data sent to wb
  output wire [31:0]     out,                    // to GPIO
  output wire [4:0]      exceptions              // on hold for now 
);
  wire la_write_en;

  wire [31:0] a;                  
  wire [31:0] b;                       	
  wire [31:0] c; 	

  wire [1:0]  op_in;
  wire [1:0]  op_out;	

  wire [2:0]  round_mode;

  wire [10:0] valid_in;                          // (sqrt, div, fma, multi, add-sub, f2i, i2f, min-max, comp, sign_inj, f-class)
  wire [10:0] valid_out;	
  
  wire [31:0] fclass_out;

  wire [4:0]  cmp_exceptions;
  wire [31:0] cmp_out;

  wire [4:0]  min_max_exceptions;
  wire [31:0] min_max_out;

  wire [4:0]  itof_exceptions;
  wire [31:0] itof_out;

  wire [4:0]  ftoi_exceptions;
  wire [31:0] ftoi_out;

  wire [31:0] sinj_out;

  wire [4:0]  add_sub_exceptions;
  wire [31:0] add_sub_out;

  wire [4:0]  mul_exceptions;
  wire [31:0] mul_out;

  wire [4:0]  mac_exceptions;
  wire [31:0] mac_out;

  wire [4:0]  sqrt_exceptions;
  wire [31:0] sqrt_out;    
     		      	       		
  wire [4:0]  div_exceptions;       		      		
  wire [31:0] div_out;         
  wire        div_valid_out;    
  wire        sqrt_valid_out;   
  
  wire [4:0]  excep_temp;   
  wire [31:0] out_temp;

  wire [31:0] int_rddata;
  wire [31:0] addr;        

  wire        wb_valid_f;
  wire        wb_valid_ns;

  wire [31:0] fpu_result;
  wire [31:0] data;

  assign la_write_en              = |la_write;
  assign addr                     = la_write_en ? la_addr : rdwraddr;
  assign data                     = la_write_en ? la_data : wrdata;
             		    		
  fpu_registers csrs             ( .clk             (clk                      ),
                                   .rst_l           (rst_l                    ),
                                   .fpu_result      (fpu_result               ),
                                   .fpu_valids      ({valid_out, op_out}      ),
                                   .addr            (addr                     ),
                                   .wren            (wb_valid | la_write_en   ),
                                   .wrdata          (data                     ),
                                   .exceptions      (exceptions               ),
                                   .rddata          (int_rddata               ),
                                   .opA             (a                        ),
                                   .opB             (b                        ),
                                   .opC             (c                        ),
                                   .frm             (round_mode               ),
                                   .op_valids       ({valid_in, op_in}        ),
                                   .ack             (ack                      ),
                                   .result          (out                      ));  

  f_class #(8,24) fpu_fclass      ( .in             (a                        ),
                                    .result         (fclass_out               ) );

  sign_inject #(8,24) fpu_sgn_inj ( .a              (a                        ),
                                    .b              (b                        ),
                                    .op             (op_in                    ),
                                    .out            (sinj_out                 ) );

  compare #(8,24) fpu_comp        ( .a              (a                        ),
                                    .b              (b                        ),
                                    .op             (op_in                    ),
                                    .out            (cmp_out                  ),
                                    .exceptions     (cmp_exceptions           ) );

  min_max #(8,24) fpu_min_max     ( .a              (a                        ),
                                    .b              (b                        ),
                                    .op             (op_in[0]                 ),
                                    .out            (min_max_out              ), 
                                    .exceptions     (min_max_exceptions       ) );

  int_to_float #(32,8,24) fpu_i2f ( .signed_in      (op_in[0]                 ),
                                    .num            (a                        ),
                                    .round_mode     (round_mode               ),
                                    .out            (itof_out                 ),
                                    .exceptions     (itof_exceptions          ) );

  float_to_int #(8,24) fpu_f2i    ( .num            (a                        ),
                                    .round_mode     (round_mode               ),
                                    .signed_out     (op_in[0]                 ),
                                    .out            (ftoi_out                 ),
                                    .int_exceptions (ftoi_exceptions          ) );

  add_sub fpu_add_sub             ( .in_x           (a                        ),
                                    .in_y           (b                        ),
                                    .operation      (op_in[0]                 ),
                                    .round_mode     (round_mode               ),
                                    .out_z          (add_sub_out              ),
                                    .exceptions     (add_sub_exceptions       ) );

  multiplier #(8,24) fpu_mult     ( .a              (a                        ),
                                    .b              (b                        ),
                                    .round_mode     (round_mode               ),
                                    .exceptions     (mul_exceptions           ),
                                    .out            (mul_out                  ) );

  fused_multiply #(8,24) fpu_fma ( .a               (a                        ),
                                   .b               (b                        ),
                                   .c               (c                        ),
                                   .op              (op_in                    ),
                                   .round_mode      (round_mode               ),
                                   .out             (mac_out                  ),          
                                   .exceptions      (mac_exceptions           ) );

  divider #(8,24) fpu_divider    ( .rst_l           (rst_l                    ),
                                   .clk             (clk                      ),
                                   .in_valid        (valid_in[9]              ),
                                   .a               (a                        ),
                                   .b               (b                        ),
                                   .round_mode      (round_mode               ),
                                   .cancel          (1'b0                     ),
                                   .in_ready        (                         ),
                                   .out_valid       (div_valid_out            ),
                                   .out             (div_out                  ),
                                   .exceptions      (div_exceptions           ) );

  sqrt #(8,24) fpu_sqrt          ( .clk             (clk                      ),
                                   .rst_l           (rst_l                    ),
                                   .in_valid        (valid_in[10]             ),
                                   .a               (a                        ),
                                   .round_mode      (round_mode               ),
                                   .cancel          (1'b0                     ),
                                   .in_ready        (                         ),
                                   .out_valid       (sqrt_valid_out           ),
                                   .out             (sqrt_out                 ),
                                   .exceptions      (sqrt_exceptions          ) );

// check for illegal op in case of sign inject and compare result
  assign illegal_op               = ((valid_in[1] || valid_in[2]) && (op_in == 2'b11)) ? 1'b1 : 1'b0;

// output operation performed
  assign op_out                   = ({valid_in[1] || valid_in[2] || valid_in[3] || valid_in[4] || 
                                      valid_in[5] || valid_in[6] || valid_in[8]}) ? op_in : 2'b0;
  
  assign valid_out                = {sqrt_valid_out,div_valid_out,valid_in[8:0]};

  assign wb_valid_ns              = (|valid_out | wb_valid | la_write_en) ? (wb_valid | la_write_en) : wb_valid_f;

  rvdff #(1) wb_valid_ff (.clk(clk), .rst_l(rst_l), .din(wb_valid_ns), .dout(wb_valid_f));

// return output data according to module enable
  assign {fpu_result, exceptions} = ({37{illegal_op}}                   & {32'b0      ,5'b0              })  |
                                    ({37{sqrt_valid_out & wb_valid_f}}  & {sqrt_out   ,sqrt_exceptions   })  |
                                    ({37{div_valid_out  & wb_valid_f}}  & {div_out    ,div_exceptions    })  |
                                    ({37{valid_in[8]    & wb_valid_f}}  & {mac_out    ,mac_exceptions    })  |
                                    ({37{valid_in[7]    & wb_valid_f}}  & {mul_out    ,mul_exceptions    })  |
                                    ({37{valid_in[6]    & wb_valid_f}}  & {add_sub_out,add_sub_exceptions})  |
                                    ({37{valid_in[5]    & wb_valid_f}}  & {ftoi_out   ,ftoi_exceptions   })  |
                                    ({37{valid_in[4]    & wb_valid_f}}  & {itof_out   ,itof_exceptions   })  |
                                    ({37{valid_in[3]    & wb_valid_f}}  & {min_max_out,min_max_exceptions})  |
                                    ({37{valid_in[2]    & wb_valid_f}}  & {cmp_out    ,cmp_exceptions    })  |
                                    ({37{valid_in[1]    & wb_valid_f}}  & {sinj_out   ,5'b0              })  |
                                    ({37{valid_in[0]    & wb_valid_f}}  & {fclass_out ,5'b0              }); 

// data to be read from memory
  assign rddata                  =  wb_valid_f ? 32'b0 : la_write_en ? (la_write & la_data) : int_rddata;

endmodule
	
	
	
// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the wire
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // wire Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb,

	output [2:0]irq
);
    wire clk;
    wire rst;

    wire [31:0] rdata; 
    wire [31:0] wdata;
    //wire [BITS-1:0] signal_received;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i && (|wbs_sel_i) && wbs_we_i; 
    //assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;

    // IO
    assign io_out[37:32] = 6'b0;
    assign io_oeb = {(37){rst}};

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, io_out};
    // Assuming LA probes [31:0] are for controlling the input register  
    assign la_write = ~la_oenb[31:0] & ~valid;
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[32]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[33]) ? la_data_in[65]: wb_rst_i;


	wire illegal_op;
    wire [4:0]exceptions;

	assign irq = illegal_op ? 3'b001 : exceptions[0] ? 3'b010 : exceptions[1] ? 3'b011 : exceptions[2] ? 3'b100 : exceptions[3] ? 					 3'b101 : 3'b000;



  fpu_top fpu (
	.clk(clk),                    
	.rst_l(~rst),                         
	//.wren(|wstrb),
	.wb_valid(valid),
	.la_write(la_write),
	.la_data(la_data_in[63:32]),
	.la_addr(la_data_in[31:0]),
	.rdwraddr(wbs_adr_i),
	.wrdata(wdata),
	.rddata(rdata),
	.illegal_op(illegal_op),
	.ack(wbs_ack_o),
	.exceptions(exceptions),
	.out(io_out[31:0]));

endmodule

`default_nettype wire	
