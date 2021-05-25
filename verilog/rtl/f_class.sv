// `include "fpu_lib.sv"

module f_class #(parameter  exp_width = 8, parameter mant_width = 24) 
(
  input  wire [(exp_width + mant_width)-1:0] in,

  output wire [31:0] result
);
  wire [9:0] value_check;

  special_check special_chk (.in(in), .result(value_check));

  assign result = {22'b0, value_check};
  
endmodule
