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

