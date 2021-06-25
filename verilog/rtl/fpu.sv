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

  assign la_write_en              = |la_write;
  assign addr                     = la_write_en ? la_addr : rdwraddr;
             		    		
  fpu_registers csrs             ( .clk             (clk                      ),
                                   .rst_l           (rst_l                    ),
                                   .fpu_result      (out                      ),
                                   .fpu_valids      ({valid_out, op_out}      ),
                                   .addr            (addr                     ),
                                   .wren            (wb_valid                 ),
                                   .wrdata          (wrdata                   ),
                                   .exceptions      (exceptions               ),
                                   .rddata          (int_rddata               ),
                                   .opA             (a                        ),
                                   .opB             (b                        ),
                                   .opC             (c                        ),
                                   .frm             (round_mode               ),
                                   .op_valids       ({valid_in, op_in}        ),
                                   .ack             (ack                      ));  

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
                                   .in_ready        (in_ready                 ),
                                   .out_valid       (div_valid_out            ),
                                   .out             (div_out                  ),
                                   .exceptions      (div_exceptions           ) );

  sqrt #(8,24) fpu_sqrt          ( .clk             (clk                      ),
                                   .rst_l           (rst_l                    ),
                                   .in_valid        (valid_in[10]             ),
                                   .a               (a                        ),
                                   .round_mode      (round_mode               ),
                                   .cancel          (1'b0                     ),
                                   .in_ready        (in_ready                 ),
                                   .out_valid       (sqrt_valid_out           ),
                                   .out             (sqrt_out                 ),
                                   .exceptions      (sqrt_exceptions          ) );

// check for illegal op in case of sign inject and compare result
  assign illegal_op               = ((valid_in[1] || valid_in[2]) && (op_in == 2'b11)) ? 1'b1 : 1'b0;

// output operation performed
  assign op_out                   = ({valid_in[1] || valid_in[2] || valid_in[3] || valid_in[6] || valid_in[8]}) ? op_in : 2'b0;
  
  assign valid_out                = {sqrt_valid_out,div_valid_out,valid_in[8:0]};

// return output data according to module enable
  assign {out, exceptions}        = ({37{illegal_op}}              & {32'b0      ,5'b0              })  |
                                    ({37{valid_in[10 & wb_valid]}} & {sqrt_out   ,sqrt_exceptions   })  |
                                    ({37{valid_in[9] & wb_valid}}  & {div_out    ,div_exceptions    })  |
                                    ({37{valid_in[8] & wb_valid}}  & {mac_out    ,mac_exceptions    })  |
                                    ({37{valid_in[7] & wb_valid}}  & {mul_out    ,mul_exceptions    })  |
                                    ({37{valid_in[6] & wb_valid}}  & {add_sub_out,add_sub_exceptions})  |
                                    ({37{valid_in[5] & wb_valid}}  & {ftoi_out   ,ftoi_exceptions   })  |
                                    ({37{valid_in[4] & wb_valid}}  & {itof_out   ,ftoi_exceptions   })  |
                                    ({37{valid_in[3] & wb_valid}}  & {min_max_out,min_max_exceptions})  |
                                    ({37{valid_in[2] & wb_valid}}  & {cmp_out    ,cmp_exceptions    })  |
                                    ({37{valid_in[1] & wb_valid}}  & {sinj_out   ,5'b0              })  |
                                    ({37{valid_in[0] & wb_valid}}  & {fclass_out ,5'b0              }); 

// data to be read from memory
  assign rddata                  =  wb_valid ? 32'b0 : la_write_en ? (la_write & la_data) : int_rddata;

endmodule
	
	
