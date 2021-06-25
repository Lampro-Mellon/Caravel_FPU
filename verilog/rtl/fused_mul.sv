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

module fused_multiply #(parameter exp_width = 8, parameter mant_width = 24) 
(
	input  wire [(exp_width + mant_width)-1:0] a,
	input  wire [(exp_width + mant_width)-1:0] b,
	input  wire [(exp_width + mant_width)-1:0] c,
	input  wire [1:0] op,
	input  wire [2:0] round_mode,

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

	wire invalid_excep, out_is_NaN, out_is_inf, out_is_zero, out_sign;
	wire signed [(exp_width + 1):0] out_s_exp;
	wire [(mant_width + 2):0] out_mant;
	wire [(exp_width + mant_width):0] oper1, oper2, oper3;

	exponent   #(exp_width, mant_width) exp_a   (.in(a), .out(oper1));
	exponent   #(exp_width, mant_width) exp_b   (.in(b), .out(oper2));
	exponent   #(exp_width, mant_width) exp_c   (.in(c), .out(oper3));
    
  mul_add    #(exp_width, mant_width) mul_add (.op(op), .a(oper1), .b(oper2), .c(oper3), .round_mode(round_mode), .invalid_excep(invalid_excep), 
                                                .out_is_NaN(out_is_NaN), .out_is_inf(out_is_inf), .out_is_zero(out_is_zero), .out_sign(out_sign), 
                                                .out_s_exp(out_s_exp), .out_mant(out_mant) );
    
  round_excep #(exp_width, mant_width+2, exp_width,mant_width,0) round_exception 
																							( .invalid_excep(invalid_excep), .infinite_excep(1'b0), .in_is_NaN(out_is_NaN), 
																								.in_is_inf(out_is_inf), .in_is_zero(out_is_zero),.in_sign(out_sign),.in_sexp(out_s_exp), 
																								.in_mant(out_mant),.round_mode(round_mode), .result(out), .exceptions(exceptions));

endmodule

module mul_add#(parameter exp_width = 8, parameter mant_width = 24) 
(
	input  wire [(exp_width + mant_width):0] a,
	input  wire [(exp_width + mant_width):0] b,
	input  wire [(exp_width + mant_width):0] c,
	input  wire [2:0] round_mode,
	input  wire [1:0] op, 

	output wire invalid_excep,
	output wire out_is_NaN,
	output wire out_is_inf,
	output wire out_is_zero,
	output wire out_sign,
	output wire signed [(exp_width + 1):0] out_s_exp,
	output wire [(mant_width + 2):0] out_mant
);

function integer clog2;
  input integer a;
  
  begin
      a = a - 1;
      for (clog2 = 0; a > 0; clog2 = clog2 + 1) a = a>>1;
  end

endfunction

  wire [(mant_width - 1):0] mul_add_a, mul_add_b;
  wire [(mant_width*2 - 1):0] mul_add_c;
  wire [5:0] intermed_compact_state;
  wire signed [(exp_width + 1):0] intermed_sexp;
  wire [(clog2(mant_width + 1) - 1):0] inter_c_dom_calign_dist;
  wire [(mant_width + 1):0] inter_high_align_sig_c;
  wire  [mant_width*2:0] mul_add_res;

  mul_add_pre_mul#(exp_width, mant_width) pre_mul(.op(op), .a(a), .b(b), .c(c), .round_mode(round_mode), .mul_add_a(mul_add_a), 
																									 .mul_add_b(mul_add_b), .mul_add_c(mul_add_c), .intermed_compact_state(intermed_compact_state), 
																									 .intermed_sexp(intermed_sexp), .inter_c_dom_calign_dist(inter_c_dom_calign_dist), 
																									 .inter_high_align_sig_c(inter_high_align_sig_c) );

  assign mul_add_res = mul_add_a * mul_add_b + mul_add_c;
  
  mul_add_post_mul#(exp_width, mant_width)post_mul(.intermed_compact_state(intermed_compact_state), .intermed_sexp(intermed_sexp), 
																										.inter_c_dom_calign_dist(inter_c_dom_calign_dist), .inter_high_align_sig_c(inter_high_align_sig_c),
																										.mul_add_res(mul_add_res), .round_mode(round_mode), .invalid_excep(invalid_excep), 
																										.out_is_NaN(out_is_NaN), .out_is_inf(out_is_inf), .out_is_zero(out_is_zero), 
																										.out_sign(out_sign), .out_s_exp(out_s_exp), .out_mant(out_mant));

endmodule

module mul_add_pre_mul#(parameter exp_width = 8, parameter mant_width = 24) 
	(op, a, b, c, round_mode, mul_add_a, 
	mul_add_b, mul_add_c, intermed_compact_state, 
	intermed_sexp, inter_c_dom_calign_dist, 
	inter_high_align_sig_c);
	
function integer clog2;
  input integer a;
  
  begin
      a = a - 1;
      for (clog2 = 0; a > 0; clog2 = clog2 + 1) a = a>>1;
  end

endfunction

	input  wire [1:0] op;
	input  wire [(exp_width + mant_width):0] a;
	input  wire [(exp_width + mant_width):0] b;
	input  wire [(exp_width + mant_width):0] c;
	input  wire [2:0] round_mode;

	output wire [(mant_width - 1):0] mul_add_a;
	output wire [(mant_width - 1):0] mul_add_b;
	output wire [(mant_width*2 - 1):0] mul_add_c;
	output wire [5:0] intermed_compact_state;
	output wire signed [(exp_width + 1):0] intermed_sexp;
	output wire [(clog2(mant_width + 1) - 1):0] inter_c_dom_calign_dist;
	output wire [(mant_width + 1):0] inter_high_align_sig_c;

  localparam prod_width 		    	 = mant_width*2;
  localparam mant_sum_width     	 = mant_width + prod_width + 3;
	localparam c_grain_align         = (mant_sum_width - mant_width - 1) & 3;
  localparam c_extra_mask_hi_bound = (mant_sum_width - 1)/4;
  localparam c_extra_mask_lo_bound = (mant_sum_width - mant_width - 1)/4;

	wire is_a_qNaN, is_a_inf, is_a_zero, is_a_sNaN, sign_a;
	wire is_b_qNaN, is_b_inf, is_b_zero, is_b_sNaN, sign_b;
	wire is_c_qNaN, is_c_inf, is_c_zero, is_c_sNaN, sign_c;  

  wire [mant_width:0] mant_a, mant_b, mant_c;
	wire signed [(exp_width + 1):0] sexp_a, sexp_b, sexp_c, sexp_sum;
	wire signed [(exp_width + 2):0] exp_prod_aligned, s_natc_align_dist;
  
	wire sign_prod, sub_mags, op_sign_c, round_mode_min;
	wire is_min_c_align, is_c_dominant, special_sign_out;
	wire reduced_4_c_extra, is_a_orb_NaN, is_any_NaN, is_aorb_inf;
	wire invalid_prod, not_sNaN_invalid_excep, invalid_excep;
	wire not_NaN_add_zeros, special_case, special_notNaN_sign_out ;

	wire [(mant_sum_width - 1):0] aligned_mant_c;
  wire [(exp_width + 1):0] pos_nat_c_align_dist;
  wire [(clog2(mant_sum_width) - 1):0] c_align_dist;
  wire signed [(mant_sum_width + 2):0] ext_comp_mant_c;
  wire [(mant_sum_width + 1):0] main_aligned_mant_c;
  wire [(mant_width + c_grain_align):0] grain_aligned_mant_c;
  wire [(mant_width + c_grain_align)/4:0] reduced_4_mant_c;
	wire [(c_extra_mask_hi_bound - c_extra_mask_lo_bound - 1):0] c_extra_mask;

	mac_spec_check #(exp_width,mant_width ) mac_spec_check_a (.in (a), .is_qNaN (is_a_qNaN), .is_inf(is_a_inf), .is_zero(is_a_zero), 
                                                            .is_sNaN(is_a_sNaN),.sign(sign_a), .s_exp(sexp_a), .sig(mant_a) );

  mac_spec_check #(exp_width,mant_width ) mac_spec_check_b (.in (b), .is_qNaN (is_b_qNaN), .is_inf(is_b_inf), .is_zero(is_b_zero), 
                                                            .is_sNaN(is_b_sNaN),.sign(sign_b), .s_exp(sexp_b), .sig(mant_b) );
  
	mac_spec_check #(exp_width,mant_width ) mac_spec_check_c (.in(c), .is_qNaN (is_c_qNaN), .is_inf(is_c_inf), .is_zero(is_c_zero), 
  	                                                        .is_sNaN(is_c_sNaN),.sign(sign_c), .s_exp(sexp_c), .sig(mant_c) );    

  assign sign_prod          	= sign_a ^ sign_b ^ op[1];
  assign exp_prod_aligned   	= sexp_a + sexp_b + (-(1<<exp_width) + mant_width + 3);
  assign sub_mags           	= sign_prod ^ sign_c ^ op[0];
  assign op_sign_c          	= sign_prod ^ sub_mags;
  assign round_mode_min 	  	= (round_mode == `round_min);

  assign s_natc_align_dist   	= exp_prod_aligned - sexp_c;
  assign pos_nat_c_align_dist = s_natc_align_dist[(exp_width + 1):0];
  assign is_min_c_align      	= is_a_zero || is_b_zero || (s_natc_align_dist < 0);
  assign is_c_dominant      	= !is_c_zero && (is_min_c_align || (pos_nat_c_align_dist <= mant_width));
  assign sexp_sum          		= is_c_dominant ? sexp_c : exp_prod_aligned - mant_width;
  assign c_align_dist       	= is_min_c_align ? 0 : (pos_nat_c_align_dist < mant_sum_width - 1) ? 
																pos_nat_c_align_dist[(clog2(mant_sum_width) - 1):0] : mant_sum_width - 1;
  assign ext_comp_mant_c     	= {sub_mags ? ~mant_c : mant_c, {(mant_sum_width - mant_width + 2){sub_mags}}};
  assign main_aligned_mant_c  = ext_comp_mant_c>>>c_align_dist;
  assign grain_aligned_mant_c = mant_c<<c_grain_align;
  
  compress_by4#(mant_width + 1 + c_grain_align) mantc_comp (grain_aligned_mant_c, reduced_4_mant_c);
  
  low_mask_hi_lo#(clog2(mant_sum_width) - 2, c_extra_mask_hi_bound, c_extra_mask_lo_bound) 
                                extra_mask_c(c_align_dist[(clog2(mant_sum_width) - 1):2], c_extra_mask);

	assign reduced_4_c_extra 		  = |(reduced_4_mant_c & c_extra_mask);
	assign aligned_mant_c 			  = {main_aligned_mant_c>>3, sub_mags ? (&main_aligned_mant_c[2:0]) 
																	&& !reduced_4_c_extra : (|main_aligned_mant_c[2:0]) || reduced_4_c_extra};
	
	assign is_a_orb_NaN  			 		= is_a_qNaN || is_b_qNaN;
	assign is_any_NaN    			 		= is_a_orb_NaN || is_c_qNaN;
	assign is_aorb_inf   			 		= is_a_inf || is_b_inf;
	assign invalid_prod 			 		= (is_a_inf && is_b_zero) || (is_a_zero && is_b_inf);
	assign not_sNaN_invalid_excep = invalid_prod || (!is_a_orb_NaN && is_aorb_inf && is_c_inf && sub_mags);
	assign invalid_excep          = is_a_sNaN || is_b_sNaN || is_c_sNaN || not_sNaN_invalid_excep;
	assign not_NaN_add_zeros      = (is_a_zero || is_b_zero) && is_c_zero;
	assign special_case           = is_any_NaN || is_aorb_inf || is_c_inf || not_NaN_add_zeros;
	assign special_notNaN_sign_out= (is_aorb_inf && sign_prod) || (is_c_inf && op_sign_c) || (not_NaN_add_zeros && 
																	!round_mode_min && sign_prod && op_sign_c) || (not_NaN_add_zeros 
																	&& round_mode_min && (sign_prod || op_sign_c));

	assign special_sign_out 			= special_notNaN_sign_out;
	assign mul_add_a 							= mant_a;
	assign mul_add_b 							= mant_b;
	assign mul_add_c 							= aligned_mant_c[prod_width:1];
	assign intermed_compact_state = {special_case, invalid_excep || (!special_case && sign_prod        ),
													         is_any_NaN            			 || (!special_case && sub_mags         ),
         													 is_aorb_inf || is_c_inf     || (!special_case && is_c_dominant    ),
         													 not_NaN_add_zeros     			 || (!special_case && aligned_mant_c[0]),
         													 special_sign_out};
	assign intermed_sexp 					= sexp_sum;
	assign inter_c_dom_calign_dist= c_align_dist[(clog2(mant_width + 1) - 1):0];
	assign inter_high_align_sig_c = aligned_mant_c[(mant_sum_width - 1):(prod_width + 1)];

endmodule

module mul_add_post_mul#(parameter exp_width = 8, parameter mant_width = 24) 
( intermed_compact_state, intermed_sexp, inter_c_dom_calign_dist, 
	inter_high_align_sig_c, mul_add_res, round_mode, invalid_excep, 
	out_is_NaN, out_is_inf, out_is_zero, out_sign, out_s_exp, out_mant);

function integer clog2;
  input integer a;
  
  begin
      a = a - 1;
      for (clog2 = 0; a > 0; clog2 = clog2 + 1) a = a>>1;
  end

endfunction

	input wire [5:0] intermed_compact_state;
	input wire signed [(exp_width + 1):0] intermed_sexp;
	input wire [(clog2(mant_width + 1) - 1):0] inter_c_dom_calign_dist;
	input wire [(mant_width + 1):0] inter_high_align_sig_c;
	input wire [mant_width*2:0] mul_add_res;
	input wire [2:0] round_mode;

	output wire invalid_excep;
	output wire out_is_NaN;
	output wire out_is_inf;
	output wire out_is_zero;
	output wire out_sign;
	output wire signed [(exp_width + 1):0] out_s_exp;
	output wire [(mant_width + 2):0] out_mant;

	localparam prod_width 		= mant_width*2;
	localparam mant_sum_width = mant_width + prod_width + 3;
	
	wire special_case, special_sign_out;
	wire not_NaN_add_zeros, bit0AlignedSigC;
	wire sign_prod, sub_mags, is_c_dominant;
	wire op_sign_c, round_mode_min, c_dom_sign;
	wire [(mant_width + 1):0] inc_high_aligned_mant_c;
	wire [(mant_sum_width - 1):0] mant_sum;
	wire signed [(exp_width + 1):0] c_dom_sexp;
	wire [(mant_width*2 + 1):0] c_dom_abs_mant_sum;
	wire c_dom_abs_mant_sum_extra;
	wire [(mant_width + 4):0] c_dom_main_mant;
	wire [((mant_width | 3) - 1):0] c_dom_grain_align_low_mant;
	wire [mant_width/4:0] c_dom_reduce_4_low_mant;
	wire [(mant_width/4 - 1):0] cdom_mant_extra_mask;
	wire cdom_reduced_4_mant_extra;
  wire [(mant_width + 2):0] cdom_mant;
	wire not_cdom_mant_sum_sign;
	wire [(prod_width + 2):0] not_cdom_abs_mant_sum;
	wire [(prod_width + 2)/2:0] not_cdom_reduced2_abs_mant_sum;
	wire [(clog2(prod_width + 4) - 2):0] not_cdom_norm_dist_reduced2;
	wire [(clog2(prod_width + 4) - 1):0] not_cdom_near_norm_dist;                
	wire signed [(exp_width + 1):0] not_cdom_sexp;                         
	wire [(mant_width + 4):0] not_cdom_main_mant;                        
	wire [(((mant_width/2 + 1) | 1) - 1):0] cdom_grain_aligned_low_reduced2_mant;
	wire [(mant_width + 2)/4:0] not_cdom_reduced4_abs_mant_sum;
	wire [((mant_width + 2)/4 - 1):0] not_cdom_mant_extra_mask;
	wire not_cdom_reduced4_mant_extra;                                                                                           
	wire [(mant_width + 2):0] not_cdom_mant;
	wire not_cdom_complete_cancel,not_cdom_sign;
	
	assign special_case  					 = intermed_compact_state[5];
	assign invalid_excep 					 = special_case && intermed_compact_state[4];
	assign out_is_NaN    					 = special_case && intermed_compact_state[3];
	assign out_is_inf    					 = special_case && intermed_compact_state[2];
	assign not_NaN_add_zeros			 = special_case && intermed_compact_state[1];
	assign sign_prod        			 = intermed_compact_state[4];
	assign sub_mags       				 = intermed_compact_state[3];
	assign is_c_dominant     			 = intermed_compact_state[2];
	assign bit0AlignedSigC 				 = intermed_compact_state[1];
	assign special_sign_out 			 = intermed_compact_state[0];
	assign op_sign_c 				  		 = sign_prod ^ sub_mags;
	
	assign inc_high_aligned_mant_c = inter_high_align_sig_c + 1;
	assign mant_sum 							 = {mul_add_res[prod_width] ? inc_high_aligned_mant_c : inter_high_align_sig_c, 
																	  mul_add_res[(prod_width - 1):0], bit0AlignedSigC};
	assign round_mode_min 				 = (round_mode == `round_min);
  assign c_dom_sign 						 = op_sign_c;
  assign c_dom_sexp 						 = intermed_sexp - sub_mags;
  assign c_dom_abs_mant_sum 		 = sub_mags ? ~mant_sum[(mant_sum_width - 1):(mant_width + 1)] : 
                          				 {1'b0, inter_high_align_sig_c[(mant_width + 1):mant_width], 
																	 	mant_sum[(mant_sum_width - 3):(mant_width + 2)]};

	assign c_dom_abs_mant_sum_extra   = sub_mags ? !(&mant_sum[mant_width:1]) : |mant_sum[(mant_width + 1):1];
	assign c_dom_main_mant 					  = (c_dom_abs_mant_sum<<inter_c_dom_calign_dist)>>(mant_width - 3);
	assign c_dom_grain_align_low_mant = c_dom_abs_mant_sum[(mant_width - 1):0]<<(~mant_width & 3);
	
	compress_by4#(mant_width | 3) cdom_abs_mant_sum( c_dom_grain_align_low_mant, c_dom_reduce_4_low_mant);

  low_mask_lo_hi#(clog2(mant_width + 1) - 2, 0, mant_width/4) lowMask_CDom_sigExtraMask
																	(inter_c_dom_calign_dist[(clog2(mant_width + 1) - 1):2], cdom_mant_extra_mask );

	assign cdom_reduced_4_mant_extra = |(c_dom_reduce_4_low_mant & cdom_mant_extra_mask);
	assign cdom_mant 								 = {c_dom_main_mant>>3, (|c_dom_main_mant[2:0]) || cdom_reduced_4_mant_extra 
																		 || c_dom_abs_mant_sum_extra};

	assign not_cdom_mant_sum_sign 	 = mant_sum[prod_width + 3];
	assign not_cdom_abs_mant_sum 		 = not_cdom_mant_sum_sign ? ~mant_sum[(prod_width + 2):0] : 
																		 mant_sum[(prod_width + 2):0] + sub_mags;
    
  compress_by2#(prod_width + 3) not_cdom_mant_sum( not_cdom_abs_mant_sum, not_cdom_reduced2_abs_mant_sum);
    
  lead_zero_param#((prod_width + 2)/2 + 1, clog2(prod_width + 4) - 1) leading_zeros
																												(not_cdom_reduced2_abs_mant_sum, not_cdom_norm_dist_reduced2);
    
	assign not_cdom_near_norm_dist              =  not_cdom_norm_dist_reduced2<<1;
	assign not_cdom_sexp                        = intermed_sexp - not_cdom_near_norm_dist;
	assign not_cdom_main_mant                   = ({1'b0, not_cdom_abs_mant_sum}<<not_cdom_near_norm_dist)>>(mant_width-1);
	assign cdom_grain_aligned_low_reduced2_mant = not_cdom_reduced2_abs_mant_sum[mant_width/2:0]<<((mant_width/2) & 1);

	
	compress_by2#((mant_width/2 + 1) | 1) not_cdom_reduced2_absmantsum
																									(cdom_grain_aligned_low_reduced2_mant, not_cdom_reduced4_abs_mant_sum);
	
	low_mask_lo_hi#(clog2(prod_width + 4)-2,0,(mant_width + 2)/4) not_cdom_mant_mask
																 (not_cdom_norm_dist_reduced2[(clog2(prod_width + 4) - 2):1], not_cdom_mant_extra_mask );
	
	assign not_cdom_reduced4_mant_extra = |(not_cdom_reduced4_abs_mant_sum & not_cdom_mant_extra_mask);
	assign not_cdom_mant 								= {not_cdom_main_mant>>3, (|not_cdom_main_mant[2:0]) || not_cdom_reduced4_mant_extra};
	assign not_cdom_complete_cancel 		= (not_cdom_mant[(mant_width + 2):(mant_width + 1)] == 0);
	assign not_cdom_sign 							  = not_cdom_complete_cancel ? round_mode_min : sign_prod ^ not_cdom_mant_sum_sign;
	
	assign out_is_zero 									= not_NaN_add_zeros || (!is_c_dominant && not_cdom_complete_cancel);
	assign out_sign 										= (special_case && special_sign_out) || (!special_case &&  is_c_dominant && c_dom_sign) 
																				|| (!special_case && !is_c_dominant && not_cdom_sign   );
	assign out_s_exp 										= is_c_dominant ? c_dom_sexp : not_cdom_sexp;

	assign out_mant 										= is_c_dominant ? cdom_mant : not_cdom_mant;

endmodule
