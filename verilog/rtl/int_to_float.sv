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

module int_to_float #(parameter int_width = 32, parameter exp_width = 8, parameter sig_width = 24)
(
// if number is negative signed_in should be 1  
  input  wire                    signed_in,
  input  wire [(int_width-1):0]  num,
  input  wire [2:0]              round_mode,

  output wire [(exp_width+sig_width)-1:0] out,
  output wire [4:0]              exceptions
);
  wire        sign;
  wire        is_zero,rounding_overflow;

  wire [4:0]  index, shift_amount;
  wire [22:0] mantissa;
  wire [7:0]  exp;
  wire [31:0] shifted_num;
  wire [26:0] mant;
  wire [23:0] rounded_mantissa;
  wire [31:0] new_num;
  wire invalid;
  wire div_by_zero;
  wire overflow;
  wire underflow;
  wire inexact;

// check if input number is zero
  assign is_zero          = !(|num);
// determining sign of result  
  assign sign             = signed_in && num[int_width-1];
  assign new_num          = sign ? -num : num;

// position of leading one  
  leading_ones lead_one ( .in  (new_num), .out (index));

// calculating shift amount of the basis of leading one
  assign shift_amount = 5'd31 - index;
// shifting number 
  assign shifted_num = new_num << shift_amount;

// compress number to 27 bits
  assign mant = {shifted_num[31:6], |shifted_num[5:0]};
  
// rounding the number  
  rounding rounder(.sign(sign), .mantisa(mant), .round_mode(round_mode), .rounded_mantisa(rounded_mantissa), .rounding_overflow(rounding_overflow));

// exponent of the result  
  assign exp              = index + 8'd127 + rounding_overflow;
// mantissa of the result  
  assign mantissa         = rounded_mantissa[22:0];
// final result  
  assign out              = is_zero ? {32'd0} : {sign, exp, mantissa};

// redundant exceptions
  assign invalid          = 1'b0; 
  assign div_by_zero      = 1'b0;
  assign overflow         = 1'b0;
  assign underflow        = 1'b0;
// inexact result flag  
  assign inexact          = |mant[2:0];
  assign exceptions       = {invalid, div_by_zero, overflow, underflow, inexact}; 

endmodule
