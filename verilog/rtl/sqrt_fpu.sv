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

module sqrt #( parameter exp_width = 8, parameter mant_width = 24, parameter options = 0)
(
	input wire clk,
	input wire rst_l,
	input wire in_valid,
	input wire [(exp_width + mant_width)-1:0] a,
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
	wire signed [(exp_width + 1):0] sexp_a;
	wire [mant_width:0] mant_a;
	wire not_sNaN_inval_excep, major_excep;
	wire is_res_NaN, is_res_inf, is_res_zero, sign_res;
	wire special_case_a, normal_case_sqrt, normal_case_s;
	wire even_sqrt, odd_sqrt;
	wire   [(clog2(mant_width + 3) - 1):0] cycle_num, cycle_num_in;
	wire   major_exc_z, not_zero_rem_z;
	wire   is_NaN_z, is_inf_z, is_zero_z, sign_z;
	wire   signed [(exp_width + 1):0] sexp_z, sexp_z_in;
	wire   [(mant_width - 2):0] mant_b_z;
	wire   [2:0] round_mode_z;
	wire   [(mant_width + 1):0] rem_z, rem_z_in;
	wire   [(mant_width + 1):0] mantx_z, mantx_z_in;
	wire idle, entering, entering_norm_case, skip_cycle_2;
	
	wire [1:0] dec_hi_mant_a;
	wire [(mant_width + 2):0] rem; 
	wire [mant_width:0] bit_mask;
	wire [(mant_width + 1):0] trail_term;
	wire signed [(mant_width + 3):0] trail_rem;
	wire new_bit;
	wire [2:0] round_mode_out;
	wire invalid_excep;
	wire infinite_excep;
	wire is_out_NaN;
	wire is_out_inf;
	wire is_out_zero;
	wire out_sign;
	wire signed [(exp_width + 1):0] out_sexp;
	wire [(mant_width + 2):0] out_mant;
	wire [(exp_width + mant_width):0] num;
	wire cancel_reset;

	assign cancel_reset = rst_l & !cancel;

	exponent   #(exp_width, mant_width) exp_a   (.in(a), .out(num));

	mac_spec_check #(exp_width,mant_width ) mac_spec_check (.in(num), .is_qNaN (is_a_qNaN), .is_inf(is_a_inf), .is_zero(is_a_zero), 
                                                          .is_sNaN(is_a_sNaN),.sign(sign_a), .s_exp(sexp_a), .sig(mant_a) );
  
	assign not_sNaN_inval_excep = !is_a_qNaN && !is_a_zero && sign_a;
	assign major_excep          = is_a_sNaN || not_sNaN_inval_excep;
	assign is_res_NaN           =  is_a_qNaN || not_sNaN_inval_excep; 

	assign is_res_inf  			    = is_a_inf;  
	assign is_res_zero 			    = is_a_zero; 
	assign sign_res    			    = sign_a; 
	assign special_case_a 	    = is_a_qNaN || is_a_inf || is_a_zero;
	assign normal_case_sqrt     = !special_case_a && !sign_a;
	assign normal_case_s 		    = normal_case_sqrt; 	
	assign even_sqrt            = !sexp_a[0];
	assign odd_sqrt             =  sexp_a[0];
	assign idle 							  = (cycle_num == 0);
	assign in_ready 					  = (cycle_num <= 1);
	assign entering 					  = in_ready && in_valid;
	assign entering_norm_case   = entering && normal_case_s;
	assign skip_cycle_2 			  = (cycle_num == 3) && mantx_z[mant_width + 1];
    
	assign cycle_num_in = (entering && !normal_case_s ? 1 : 0) 
						| (entering_norm_case ? ((sexp_a[0] ? mant_width : mant_width + 1)) : 0)
						| (!idle && !skip_cycle_2 ? cycle_num - 1 : 0)
						| (!idle &&  skip_cycle_2 ? 1            : 0);

	rvdffe #(clog2(mant_width + 3)) cycle_num_ff (.clk(clk), .rst_l(cancel_reset), .din(cycle_num_in), .en(!idle || in_valid), .dout(cycle_num));

	rvdffe #(1) major_exc_z_ff (.clk(clk), .rst_l(cancel_reset), .din(major_excep), .en(entering), .dout(major_exc_z));
	rvdffe #(1) is_NaN_z_ff (.clk(clk), .rst_l(cancel_reset), .din(is_res_NaN), .en(entering), .dout(is_NaN_z));
	rvdffe #(1) is_inf_z_ff (.clk(clk), .rst_l(cancel_reset), .din(is_res_inf), .en(entering), .dout(is_inf_z));
	rvdffe #(1) is_zero_z_ff (.clk(clk), .rst_l(cancel_reset), .din(is_res_zero), .en(entering), .dout(is_zero_z));
	rvdffe #(1) sign_z_ff (.clk(clk), .rst_l(cancel_reset), .din(sign_res), .en(entering), .dout(sign_z));

	assign sexp_z_in = (sexp_a>>>1) + (1<<(exp_width - 1));
	rvdffe #((exp_width + 2)) sexp_z_ff (.clk(clk), .rst_l(cancel_reset), .din(sexp_z_in), .en(entering_norm_case), .dout(sexp_z));
	rvdffe #(3) round_mode_z_ff (.clk(clk), .rst_l(cancel_reset), .din(round_mode), .en(entering_norm_case), .dout(round_mode_z));

	assign dec_hi_mant_a 	= mant_a[(mant_width - 1):(mant_width - 2)] - 1;
	assign rem = (in_ready && !odd_sqrt ? mant_a<<1 : 0) | (in_ready &&  odd_sqrt
			   ? {dec_hi_mant_a, mant_a[(mant_width - 3):0], 3'b0} : 0) | (!in_ready ? rem_z<<1 : 0);
	assign bit_mask   = ({{(mant_width + 2){1'b0}}, 1'b1}<<cycle_num)>>2;
	assign trail_term = (in_ready && even_sqrt ? 1<<mant_width         : 0)
					  | (in_ready && odd_sqrt  ? 5<<(mant_width - 1)   : 0)
					  | (!in_ready  ? mantx_z<<1 | bit_mask : 0);
	assign trail_rem = rem - trail_term;
	assign new_bit = (0 <= trail_rem);
	
	assign rem_z_in = new_bit ? trail_rem : rem;
	rvdffe #((mant_width + 2)) rem_z_ff (.clk(clk), .rst_l(cancel_reset), .din(rem_z_in), .en(entering_norm_case || (cycle_num > 2)), .dout(rem_z));
	rvdffe #(1) not_zero_rem_z_ff (.clk(clk), .rst_l(cancel_reset), .din((trail_rem != 0)), .en(entering_norm_case || (!in_ready && new_bit)), .dout(not_zero_rem_z));

	assign mantx_z_in = ( in_ready              ? 1<<mant_width             : 0)
                          |( in_ready && odd_sqrt  ? new_bit<<(mant_width - 1) : 0)
                          |(!in_ready              ? mantx_z | bit_mask        : 0);
	rvdffe #((mant_width + 2)) mantx_z_ff (.clk(clk), .rst_l(cancel_reset), .din(mantx_z_in), .en(entering_norm_case || (!in_ready && new_bit)), .dout(mantx_z));

	assign out_valid      = (cycle_num == 1);
	assign round_mode_out = round_mode_z;
	assign invalid_excep  = major_exc_z &&  is_NaN_z;
	assign infinite_excep = 1'b0;
	assign is_out_NaN     = is_NaN_z;
	assign is_out_inf     = is_inf_z;
	assign is_out_zero    = is_zero_z;
	assign out_sign       = sign_z;
	assign out_sexp       = sexp_z;
	assign out_mant       = {mantx_z, not_zero_rem_z};
  
	round_excep #(exp_width, mant_width+2, exp_width,mant_width,0) round_exception 
																							( .invalid_excep(invalid_excep), .infinite_excep(infinite_excep), .in_is_NaN(is_out_NaN), 
																								.in_is_inf(is_out_inf), .in_is_zero(is_out_zero),.in_sign(out_sign),.in_sexp(out_sexp), 
																								.in_mant(out_mant),.round_mode(round_mode), .result(out), .exceptions(exceptions));

endmodule
