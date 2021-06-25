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

module f_class #(parameter  exp_width = 8, parameter mant_width = 24) 
(
  input  wire [(exp_width + mant_width)-1:0] in,

  output wire [31:0] result
);
  wire [9:0] value_check;

  special_check special_chk (.in(in), .result(value_check));

  assign result = {22'b0, value_check};
  
endmodule
