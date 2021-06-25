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

module divider#( parameter exp_width = 8, parameter mant_width = 24, parameter options = 0) 
(
  input wire rst_l,
  input wire clk,  
  input wire in_valid,
  input wire [(exp_width + mant_width)-1:0] a,
  input wire [(exp_width + mant_width)-1:0] b,
  input wire [2:0] round_mode,
  input wire cancel,

  output wire in_ready,
  output wire out_valid,
  output wire [(exp_width + mant_width)-1:0] out,
  output wire [4:0] exceptions
);

function integer clog2;
  input integer a;
  
  begin
      a = a - 1;
      for (clog2 = 0; a > 0; clog2 = clog2 + 1) a = a>>1;
  end

endfunction
  
  wire is_a_qNaN, is_a_inf, is_a_zero, is_a_sNaN, sign_a;
	wire signed [(exp_width+1):0] sexp_a;
	wire [mant_width:0] mant_a;
  
  wire is_b_qNaN, is_b_inf, is_b_zero, is_b_sNaN, sign_b;
	wire signed [(exp_width+1):0] sexp_b;
	wire [mant_width:0] mant_b;
  wire [(exp_width + mant_width):0] oper1, oper2;
	
  wire [2:0] roundingModeOut;
  wire invalid_excep;
  wire infinite_excep;
  wire is_out_NaN;
  wire is_out_inf;
  wire is_out_zero;
  wire out_sign;
  wire signed [(exp_width + 1):0] out_sexp;
  wire [(mant_width + 2):0] out_mant;

  wire not_sNaN_invalid_exc ;
  wire major_excep;
  wire is_res_NaN;
  wire is_res_inf;
  wire is_res_zero;
  wire sign_res;
  wire spec_case_a;
  wire spec_case_b;
  wire norm_case;
  wire signed [(exp_width + 2):0] sexp_quot; 
  wire signed [(exp_width + 1):0] s_sat_exp_quot;

  wire [(clog2(mant_width + 3) - 1):0] cycle_num, cycle_num_in;
  wire major_exc_z;
  wire is_NaN_z, is_inf_z, is_zero_z, sign_z;
  wire signed [(exp_width + 1):0] sexp_z;
  wire [(mant_width - 2):0] mant_b_z;
  wire [2:0] round_mode_z;
  
  wire [(mant_width + 1):0] rem_z, rem_z_in;
  wire not_zero_rem_z;
  wire [(mant_width + 1):0] mantx_z, mantx_z_in;
  wire idle;
  wire entering; 
  wire entering_norm_case;
  wire skipCycle2; 

  wire [1:0] dec_hi_mant_a;
  wire [(mant_width + 2):0] rem;
  wire [mant_width:0] bit_mask;
  wire [(mant_width + 1):0] trail_term;
  wire signed [(mant_width + 3):0] trail_rem;
  wire new_bit;
  wire cancel_reset;

  assign cancel_reset = rst_l & !cancel;
  
  exponent   #(exp_width, mant_width) exp_a   (.in(a), .out(oper1));
  exponent   #(exp_width, mant_width) exp_b   (.in(b), .out(oper2));

  mac_spec_check #(exp_width,mant_width ) mac_spec_check_a (.in(oper1), .is_qNaN (is_a_qNaN), .is_inf(is_a_inf), .is_zero(is_a_zero), 
                                                          .is_sNaN(is_a_sNaN),.sign(sign_a), .s_exp(sexp_a), .sig(mant_a) );
  

  mac_spec_check #(exp_width,mant_width ) mac_spec_check_b (.in(oper2), .is_qNaN (is_b_qNaN), .is_inf(is_b_inf), .is_zero(is_b_zero), 
                                                          .is_sNaN(is_b_sNaN),.sign(sign_b), .s_exp(sexp_b), .sig(mant_b) );

  assign not_sNaN_invalid_exc = (is_a_zero && is_b_zero) || (is_a_inf && is_b_inf);
  assign major_excep          = is_a_sNaN || is_b_sNaN || not_sNaN_invalid_exc || (!is_a_qNaN && !is_a_inf && is_b_zero);
  assign is_res_NaN           = is_a_qNaN || is_b_qNaN || not_sNaN_invalid_exc;

  assign is_res_inf           = is_a_inf  || is_b_zero;
  assign is_res_zero          = is_a_zero || is_b_inf;
  assign sign_res             = sign_a ^ sign_b;

  assign spec_case_a          = is_a_qNaN || is_a_inf || is_a_zero;
  assign spec_case_b          = is_b_qNaN || is_b_inf || is_b_zero;
  assign norm_case            = !spec_case_a && !spec_case_b;
  
  assign sexp_quot            = sexp_a + {{3{sexp_b[exp_width]}}, ~sexp_b[(exp_width - 1):0]};
  assign s_sat_exp_quot       = {(7<<(exp_width - 2) <= sexp_quot) ? 4'b0110 : 
                                sexp_quot[(exp_width + 1):(exp_width - 2)], sexp_quot[(exp_width - 3): 0]};

  assign idle                = (cycle_num == 0);
  assign in_ready            = (cycle_num <= 1);
  assign entering            = in_ready && in_valid;
  assign entering_norm_case  = entering && norm_case;
  assign skipCycle2          = (cycle_num == 3) && mantx_z[mant_width + 1];
  
  assign cycle_num_in = (entering && !norm_case ? 1 : 0)  
                      | (entering_norm_case   ?  (mant_width + 2) : 0)
                      | (!idle && !skipCycle2  ? cycle_num - 1 : 0)
                      | (!idle &&  skipCycle2  ? 1            : 0);

  rvdffe #(clog2(mant_width + 3)) cycle_num_ff (.clk(clk), .rst_l(cancel_reset), .din(cycle_num_in), .en(!idle || in_valid), .dout(cycle_num));
 
  rvdffe #(1) major_exc_z_ff (.clk(clk), .rst_l(cancel_reset), .din(major_excep), .en(entering), .dout(major_exc_z));
  rvdffe #(1) is_NaN_z_ff (.clk(clk), .rst_l(cancel_reset), .din(is_res_NaN), .en(entering), .dout(is_NaN_z));
  rvdffe #(1) is_inf_z_ff (.clk(clk), .rst_l(cancel_reset), .din(is_res_inf), .en(entering), .dout(is_inf_z));
  rvdffe #(1) is_zero_z_ff (.clk(clk), .rst_l(cancel_reset), .din(is_res_zero), .en(entering), .dout(is_zero_z));
  rvdffe #(1) sign_z_ff (.clk(clk), .rst_l(cancel_reset), .din(sign_res), .en(entering), .dout(sign_z));

  rvdffe #((exp_width + 2)) sexp_z_ff (.clk(clk), .rst_l(cancel_reset), .din(s_sat_exp_quot), .en(entering_norm_case), .dout(sexp_z));
  rvdffe #(3) round_mode_z_ff (.clk(clk), .rst_l(cancel_reset), .din(round_mode), .en(entering_norm_case), .dout(round_mode_z));
  rvdffe #((mant_width - 1)) mant_b_z_ff (.clk(clk), .rst_l(cancel_reset), .din(mant_b[(mant_width - 2):0]), .en(entering_norm_case), .dout(mant_b_z));

  assign dec_hi_mant_a        = mant_a[(mant_width - 1):(mant_width - 2)] - 1;
  assign rem                  = (in_ready ? mant_a<<1 : 0) | (!in_ready ? rem_z<<1 : 0);
  assign bit_mask             = ({{(mant_width + 2){1'b0}}, 1'b1}<<cycle_num)>>2;
  assign trail_term           = ( in_ready ? mant_b<<1           : 0)
                               |(!in_ready ? {1'b1, mant_b_z}<<1 : 0);
  assign trail_rem            = rem - trail_term;
  assign new_bit              = (0 <= trail_rem);
  
  assign rem_z_in = new_bit ? trail_rem : rem;
  rvdffe #((mant_width + 2)) rem_z_ff (.clk(clk), .rst_l(cancel_reset), .din(rem_z_in), .en(entering_norm_case || (cycle_num > 2)), .dout(rem_z));
  rvdffe #(1) not_zero_rem_z_ff (.clk(clk), .rst_l(cancel_reset), .din((trail_rem != 0)), .en(entering_norm_case || (!in_ready && new_bit)), .dout(not_zero_rem_z));

  assign mantx_z_in = ( in_ready ? new_bit<<(mant_width + 1) : 0)
                      | (!in_ready ? mantx_z | bit_mask       : 0);
  rvdffe #((mant_width + 2)) mantx_z_ff (.clk(clk), .rst_l(cancel_reset), .din(mantx_z_in), .en(entering_norm_case || (!in_ready && new_bit)), .dout(mantx_z));

  assign out_valid        = (cycle_num == 1);
  assign roundingModeOut  = round_mode_z;
  assign invalid_excep    = major_exc_z &&  is_NaN_z;
  assign infinite_excep   = major_exc_z && !is_NaN_z;
  assign is_out_NaN       = is_NaN_z;
  assign is_out_inf       = is_inf_z;
  assign is_out_zero      = is_zero_z;
  assign out_sign         = sign_z;
  assign out_sexp         = sexp_z;
  assign out_mant         = {mantx_z, not_zero_rem_z};

  round_excep #(exp_width, mant_width+2, exp_width,mant_width,0) round_exception 
																							( .invalid_excep(invalid_excep), .infinite_excep(infinite_excep), .in_is_NaN(is_out_NaN), 
																								.in_is_inf(is_out_inf), .in_is_zero(is_out_zero),.in_sign(out_sign),.in_sexp(out_sexp), 
																								.in_mant(out_mant),.round_mode(round_mode), .result(out), .exceptions(exceptions));

endmodule
