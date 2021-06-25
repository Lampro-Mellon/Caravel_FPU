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

module compare#(parameter exp_width = 8, parameter mant_width = 24)
(
  input  wire [(exp_width + mant_width)-1:0]  a,
  input  wire [(exp_width + mant_width)-1:0]  b,
  input  wire [1:0]                           op, 

  output wire [(exp_width + mant_width)-1:0]  out,
  output wire [4:0]                           exceptions 
);
  wire lt, gt, eq, unordered;
  wire                    sign_a, sign_b;
  wire [exp_width-1:0]    exp_a, exp_b;
  wire [mant_width-2:0]   mant_a, mant_b;

  wire is_a_zero, is_a_inf, is_a_qNaN, is_a_sNaN;
  wire is_b_zero, is_b_inf, is_b_qNaN, is_b_sNaN;
  wire both_inf, both_zero;
  wire ordered, exp_equal;
  wire lt_mag, eq_mag, ordered_eq, ordered_lt;
  wire invalid, div_by_zero, overflow, underflow, inexact;
  wire [9:0] spec_value_chk_a, spec_value_chk_b;


// extracting sign,exponent and mantissa of numbers
  assign {sign_a,exp_a,mant_a} = a;
  assign {sign_b,exp_b,mant_b} = b;

// module to check for special values
  special_check #(exp_width,mant_width) special_check_a (.in (a), .result(spec_value_chk_a));
  special_check #(exp_width,mant_width) special_check_b (.in (b), .result(spec_value_chk_b));

  assign is_a_zero = spec_value_chk_a[3] | spec_value_chk_a[4];
  assign is_a_inf  = spec_value_chk_a[0] | spec_value_chk_a[7];
  assign is_a_qNaN = spec_value_chk_a[9];
  assign is_a_sNaN = spec_value_chk_a[8];

  assign is_b_zero = spec_value_chk_b[3] | spec_value_chk_b[4];
  assign is_b_inf  = spec_value_chk_b[0] | spec_value_chk_b[7];
  assign is_b_qNaN = spec_value_chk_b[9];
  assign is_b_sNaN = spec_value_chk_b[8];

// check if inputs are valid or not
  assign ordered     = !(is_a_qNaN || is_b_qNaN) && !(is_a_sNaN || is_b_sNaN);  
  assign both_inf    = is_a_inf  && is_b_inf;
  assign both_zero   = is_a_zero && is_b_zero;

// comparison of exponents
  assign exp_equal   = (exp_a == exp_b);

// comparison of mantissas
  assign lt_mag      = (exp_a < exp_b) || (exp_equal && (mant_a < mant_b));
  assign eq_mag      = exp_equal && (mant_a == mant_b);

// valid inputs and equal
  assign ordered_eq  = both_zero  || (sign_a == sign_b)   && (both_inf || eq_mag);

// valid inputs and a is less than b  
  assign ordered_lt  = !both_zero && ((sign_a && !sign_b) || (!both_inf && ((sign_a && !lt_mag && ! eq_mag) 
                       || (!sign_b && lt_mag))));

  assign lt          = ordered && ordered_lt;
  assign eq          = ordered && ordered_eq;
  assign gt          = ordered && !ordered_eq && !ordered_lt;

// invalid exception would be generated if any or both numbers are NaN  
  assign invalid     = is_a_sNaN || is_b_sNaN || ((is_a_qNaN || is_b_qNaN) && !(op == 3'b010));


// unordered flag is set to high if any or both inputs are NaN  
  assign unordered   = !ordered;

// hardwired exceptions that cannot be flagged in comparator
  assign div_by_zero = 1'b0;
  assign overflow    = 1'b0;
  assign underflow   = 1'b0;
  assign inexact     = 1'b0;

  assign exceptions  = {invalid, div_by_zero, overflow, underflow, inexact};    


  assign out         = ({32{op == 3'b10}} & {31'b0,eq})                              |
                       ({32{op == 3'b01}} & {31'b0,lt})                              |
                       ({32{op == 3'b00}} & ({31'b0,lt} | {31'b0,eq}));

endmodule
