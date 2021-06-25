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

module min_max#(parameter exp_width = 8, parameter mant_width = 24)
(
  input wire [(exp_width + mant_width)-1:0]  a,
  input wire [(exp_width + mant_width)-1:0]  b,
  input wire                                 op, // 1 will return max, 0 will return min

  output wire [(exp_width + mant_width)-1:0] out,
  output wire [4:0]                          exceptions 
);

  wire [(exp_width + mant_width)-1:0] max, min, qnan, snan;
  wire [9:0] check_a, check_b;
  wire comp, both_zero, a_nan, b_nan;
  wire pos_comp;
  wire invalid;

  special_check #(exp_width, mant_width) spec_check_a (.in(a), .result(check_a));
  special_check #(exp_width, mant_width) spec_check_b (.in(b), .result(check_b));

  assign both_zero    = (check_a [3] | check_a [4]) & (check_b [3] | check_b [4]) ;

  assign pos_comp     = (a[(exp_width + mant_width)-2:mant_width-1] == b[(exp_width + mant_width)-2:mant_width-1]) ? 
                        (a[mant_width-2:0] < b[mant_width-2:0]) : (a[(exp_width + mant_width)-2:mant_width-1] < 
                         b[(exp_width + mant_width)-2:mant_width-1]);

  assign comp         = (check_a[1] | check_a[2] | check_a[3]) & (check_b[5] | check_b[6] | check_b[4]) ? 1'b1 : 
                        (check_b[1] | check_b[2] | check_b[3]) & (check_a[5] | check_a[6] | check_a[4]) ? 1'b0 : 
                        (check_a[1] | check_a[2] | check_a[3]) & (check_b[1] | check_b[2] | check_b[3]) ? !pos_comp : pos_comp;
  

  assign max          = (both_zero & check_a[4]) ? a : (both_zero & check_a[3]) ? b : check_a[7] ? a : check_a[0] ? 
                         b : check_b[0] ? a : comp ? b : a;

  assign min          = (both_zero & check_a[4]) ? b : (both_zero & check_a[3]) ? a : check_a[7] ? b : check_a[0] ?
                         a : check_b[0] ? b : comp ? a : b;
  
  assign qnan         = 32'h7fc00000;
  
  assign invalid      = check_a[8] || check_b[8];

  assign out          = (((check_a[9] && check_b[9]) | (check_a[8] && check_b[8]) | (check_a[8] & check_b[9]) | (check_a[9] & check_b[8]))
                         ? qnan :((check_a[9] | check_a[8]) ? b : ((check_b[9] | check_b[8]) ? a : (op ? max : min))));
  
  assign exceptions   = {invalid, 4'b0};

endmodule 

  
