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

module multiplier #(parameter exp_width = 8, parameter mant_width = 24) 
(
  input  wire [(exp_width + mant_width-1):0] a,  
  input  wire [(exp_width + mant_width-1):0] b,  
  input  wire [2:0]                          round_mode,

  output wire [4:0]                          exceptions,
  output wire [(exp_width + mant_width)-1:0] out
);
  
  localparam norm_dis_width = 5;

  wire sign_a, sign_b, sign_res;
  wire exp_a_zero, mant_a_zero, exp_b_zero, mant_b_zero;
  wire is_a_zero , is_a_special,is_b_zero , is_b_special;    
  wire is_out_inf, is_out_zero, is_out_NaN;   
  wire invalid_excep, infinite_excep;

  wire [9:0]                    check_a, check_b;
  wire [exp_width:0]            adj_exp_a, adj_exp_b;          
  wire [exp_width:0]            expa, expb;
  wire [(exp_width-1):0]        exp_a, exp_b;
  wire [(mant_width-2):0]       mant_a, mant_b;
  wire [(mant_width-2):0]       subnorm_mant_a, subnorm_mant_b;
  wire [(norm_dis_width - 1):0] norm_dist_a, norm_dist_b;
  wire [(exp_width+mant_width):0] oper1, oper2;

  wire                          sign_oper1, sign_oper2;
  wire [exp_width:0]            exp_oper1, exp_oper2;
  wire [(mant_width-2):0]       mant_oper1, mant_oper2;
  wire [mant_width:0]           mant_1, mant_2;
  wire signed [(exp_width+1):0] sexp_1, sexp_2;
  wire signed [(exp_width+1):0] exp_unbais;
  wire [(mant_width*2-1):0]     mant_prod;
  wire [(mant_width+2):0]       prod_comp;
  wire is_zero_oper1, is_zero_oper2;
  

  assign {sign_a, exp_a, mant_a}       = a;
  assign {sign_b, exp_b, mant_b}       = b;

  special_check #(exp_width, mant_width) spec_check_a (.in(a), .result(check_a));
  special_check #(exp_width, mant_width) spec_check_b (.in(b), .result(check_b));

  assign exp_a_zero                    = (exp_a == 0);
  assign exp_b_zero                    = (exp_b == 0);
  assign mant_a_zero                   = (mant_a == 0);
  assign mant_b_zero                   = (mant_b == 0);
  
  lead_zero_param #(mant_width-1, norm_dis_width) norm_a (mant_a, norm_dist_a);
  lead_zero_param #(mant_width-1, norm_dis_width) norm_b (mant_b, norm_dist_b);
  
  assign subnorm_mant_a                = (mant_a<<norm_dist_a)<<1;
  assign subnorm_mant_b                = (mant_b<<norm_dist_b)<<1;
  assign adj_exp_a                     = (exp_a_zero ? norm_dist_a ^ ((1<<(exp_width + 1)) - 1) : exp_a) 
                                          + ((1<<(exp_width - 1)) | (exp_a_zero ? 2 : 1));
  assign adj_exp_b                     = (exp_b_zero ? norm_dist_b ^ ((1<<(exp_width + 1)) - 1) : exp_b) 
                                          + ((1<<(exp_width - 1)) | (exp_b_zero ? 2 : 1));
  assign is_a_zero                     = exp_a_zero && mant_a_zero;
  assign is_b_zero                     = exp_b_zero && mant_b_zero;
  assign is_a_special                  = (adj_exp_a[exp_width:(exp_width - 1)] == 'b11);
  assign is_b_special                  = (adj_exp_b[exp_width:(exp_width - 1)] == 'b11);
  assign expa[exp_width:(exp_width-2)] = is_a_special ? {2'b11, !mant_a_zero} : is_a_zero ? 3'b000 
                                         : adj_exp_a[exp_width:(exp_width - 2)];
  assign expa[(exp_width - 3):0]       = adj_exp_a;
  assign expb[exp_width:(exp_width-2)] = is_b_special ? {2'b11, !mant_b_zero} : is_b_zero ? 3'b000
                                         : adj_exp_b[exp_width:(exp_width - 2)];
  assign expb[(exp_width - 3):0]       = adj_exp_b;
  assign oper1                         = {sign_a, expa, exp_a_zero ? subnorm_mant_a : mant_a};
  assign oper2                         = {sign_b, expb, exp_b_zero ? subnorm_mant_b : mant_b};
  
  assign {sign_oper1, exp_oper1, mant_oper1} = oper1;
  assign {sign_oper2, exp_oper2, mant_oper2} = oper2;
  assign is_zero_oper1                 = (exp_oper1>>(exp_width - 2) == 'b000);
  assign is_zero_oper2                 = (exp_oper2>>(exp_width - 2) == 'b000);
  assign sexp_1                        = exp_oper1;
  assign sexp_2                        = exp_oper2;
  assign mant_1                        = {1'b0, !is_zero_oper1, mant_oper1};
  assign mant_2                        = {1'b0, !is_zero_oper2, mant_oper2};
  
  assign infinite_excep                = 1'b0;
  assign invalid_excep                 = check_a[8] || check_b [8] || ((check_a[7] || check_a[0]) 
                                         && (check_b[4] || check_b [3])) || ((check_b[7] || check_b[0]) 
                                         && (check_a[4] || check_a[3]));
  assign is_out_inf                    = check_a[7] || check_a[0] || check_b[7] || check_b [0];
  assign is_out_zero                   = check_a[4] || check_a[3] || check_b[4] || check_b [3];
  assign is_out_NaN                    = check_a[9] || check_b[9];
  assign sign_res                      = sign_a ^ sign_b;
  assign exp_unbais                    = sexp_1 + sexp_2 - (1<<exp_width);
  assign mant_prod                     = mant_1 * mant_2;
  assign prod_comp                     = {mant_prod[(mant_width*2 - 1):(mant_width - 2)], |mant_prod[(mant_width - 3):0]};
  
  round_excep #(exp_width, mant_width+2, exp_width,mant_width,0) round_exception 
                                          ( .invalid_excep(invalid_excep), .infinite_excep(infinite_excep), .in_is_NaN(is_out_NaN), 
                                            .in_is_inf(is_out_inf), .in_is_zero(is_out_zero),.in_sign(sign_res),.in_sexp(exp_unbais), 
                                            .in_mant(prod_comp),.round_mode(round_mode), .result(out), .exceptions(exceptions));
endmodule
