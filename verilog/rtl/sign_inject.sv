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

module sign_inject#(parameter exp_width = 8, parameter mant_width = 24)
(
  input  wire [(exp_width + mant_width)-1:0] a,  
  input  wire [(exp_width + mant_width)-1:0] b,
  input  wire [1:0] op,

  output wire [(exp_width + mant_width)-1:0] out
);

  wire                    sign_a, sign_b;
  wire [exp_width-1:0]    exp_a , exp_b;
  wire [mant_width-2:0]   mant_a, mant_b;

  assign {sign_a, exp_a, mant_a} = a;
  assign {sign_b, exp_b, mant_b} = b;

  assign out = ({32{op == 2'b00}} & {sign_b, exp_a, mant_a})      |
               ({32{op == 2'b01}} & {!sign_b, exp_a, mant_a})     |
               ({32{op == 2'b10}} & {sign_a^sign_b, exp_a, mant_a});


endmodule

