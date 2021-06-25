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

`include "defs.vi"

module special_check #(parameter  exp_width = 8, parameter mant_width = 24) 
(
  input  wire [(exp_width + mant_width-1):0] in,

  output wire [9:0] result
);

  wire is_pos_zero;
  wire is_neg_zero;
  wire is_pos_inf;
  wire is_neg_inf;
  wire is_pos_subnorm;
  wire is_neg_subnorm;
  wire is_pos_norm;
  wire is_neg_norm;
  wire is_qNaN;
  wire is_sNaN;

  wire                    sign;
  wire [exp_width-1:0]    exp;
  wire [(mant_width-2):0] sig;

  wire exp_zero, exp_one, sig_zero; 


  assign {sign, exp, sig} = in;

  assign exp_zero         = |exp ? 1'b0 : 1'b1;
  assign sig_zero         = |sig ? 1'b0 : 1'b1;     
  assign exp_one          = &exp ? 1'b1 : 1'b0;

  assign is_pos_zero      = !sign     & exp_zero  & sig_zero;
  assign is_neg_zero      =  sign     & exp_zero  & sig_zero;
  assign is_pos_subnorm   = !sign     & exp_zero  & !sig_zero;
  assign is_neg_subnorm   =  sign     & exp_zero  & !sig_zero;
  assign is_pos_inf       = !sign     & exp_one   & sig_zero; 
  assign is_neg_inf       =  sign     & exp_one   & sig_zero; 
  assign is_qNaN          =  exp_one  & !sig_zero & sig[22];
  assign is_sNaN          =  exp_one  & !sig_zero & !sig[22];

  assign is_pos_norm      = (is_pos_zero | is_neg_zero | is_pos_subnorm | is_neg_subnorm | is_pos_inf | is_neg_inf | 
			                      is_qNaN | is_sNaN) ? 1'b0 : ~sign ? 1'b1 : 1'b0;
 
  assign is_neg_norm      = (is_pos_zero | is_neg_zero | is_pos_subnorm | is_neg_subnorm | is_pos_inf | is_neg_inf | 
			                      is_qNaN | is_sNaN) ? 1'b0 : sign ? 1'b1 : 1'b0; 

  assign result           = {is_qNaN, is_sNaN, is_pos_inf, is_pos_norm, is_pos_subnorm, is_pos_zero, is_neg_zero, 
                            is_neg_subnorm, is_neg_norm, is_neg_inf};
endmodule

module mac_spec_check #(parameter exp_width = 3, parameter mant_width = 3)
(
	input  wire [(exp_width + mant_width):0] in,
	
	output wire is_qNaN,
	output wire is_inf,
	output wire is_zero,
	output wire is_sNaN,
	output wire sign,
	output wire signed [(exp_width+1):0] s_exp,
	output wire [mant_width:0] sig
);

	wire [exp_width:0] 			 exp;
	wire [(mant_width - 2):0] mant;
	wire is_ssNaN;
	wire is_spec;

	assign {sign, exp, mant} = in;
	
	assign is_ssNaN          = (in[(exp_width + mant_width - 1):(exp_width + mant_width - 3)] == 'b111);
	assign is_spec           = (exp>>(exp_width - 1) == 'b11);
	assign is_qNaN           = is_spec &&  exp[exp_width - 2];
	assign is_inf            = is_spec && !exp[exp_width - 2];
	assign is_zero           = (exp>>(exp_width - 2) == 'b000);
	assign is_sNaN           = is_ssNaN && !in[mant_width - 2];
	
  assign s_exp 	           = exp;
	assign sig 		           = {1'b0, !is_zero, mant};

endmodule

module rounding
(
  input  wire sign,
  input  wire [26:0] mantisa,
  input  wire [2:0] round_mode,

  output wire [23:0] rounded_mantisa,
  output wire rounding_overflow
);
  
  wire [23:0] rne, rtz, rdn, rup, rmm;
  wire rne_overflow, rtz_overflow, rdn_overflow, rup_overflow, rmm_overflow;

  assign {rne_overflow, rne} = mantisa[2] ? (|mantisa[1:0] ? ({1'b0, mantisa[26:3]} + 1'b1) 
                               : ({1'b0, mantisa[26:3]} + mantisa[3])) : {1'b0, mantisa[26:3]};

  assign {rtz_overflow, rtz} = {1'b0, mantisa[26:3]};

  assign {rdn_overflow, rdn} = |mantisa[2:0] ? (sign ? ({1'b0, mantisa[26:3]} + 1'b1) 
                                : {1'b0, mantisa[26:3]}) : {1'b0, mantisa[26:3]};

  assign {rup_overflow, rup} = |mantisa[2:0] ? (sign ? {1'b0, mantisa[26:3]} 
                                  : ({1'b0, mantisa[26:3]} + 1'b1)) : {1'b0, mantisa[26:3]};
  assign {rmm_overflow, rmm} = mantisa[2] ? ({1'b0, mantisa[26:3]} + 1'b1) : {1'b0, mantisa[26:3]};

  assign rounded_mantisa     = ({24{round_mode == 3'b000}} & rne) |
                               ({24{round_mode == 3'b001}} & rtz) |
                               ({24{round_mode == 3'b010}} & rdn) |
                               ({24{round_mode == 3'b011}} & rup) |
                               ({24{round_mode == 3'b100}} & rmm);

  assign rounding_overflow   = ((round_mode == 3'b000) & rne_overflow) |
                               ((round_mode == 3'b001) & rtz_overflow) |
                               ((round_mode == 3'b010) & rdn_overflow) |
                               ((round_mode == 3'b011) & rup_overflow) |
                               ((round_mode == 3'b100) & rmm_overflow);

endmodule


module leading_zero
(
  input  wire [23:0] in,

  output wire [4:0] out
);
  assign out[4:0]       = ({5{(in[22]  & (&(~(in[23]))))}}    & 5'd1)  |			 
 		                      ({5{(in[21]  & (&(~(in[23:22]))))}} & 5'd2)  |
 		                      ({5{(in[20]  & (&(~(in[23:21]))))}} & 5'd3)  |
 		                      ({5{(in[19]  & (&(~(in[23:20]))))}} & 5'd4)  |
 		                      ({5{(in[18]  & (&(~(in[23:19]))))}} & 5'd5)  |
 		                      ({5{(in[17]  & (&(~(in[23:18]))))}} & 5'd6)  |
 		                      ({5{(in[16]  & (&(~(in[23:17]))))}} & 5'd7)  |
 		                      ({5{(in[15]  & (&(~(in[23:16]))))}} & 5'd8)  |
 		                      ({5{(in[14]  & (&(~(in[23:15]))))}} & 5'd9)  |
 		                      ({5{(in[13]  & (&(~(in[23:14]))))}} & 5'd10) |
 		                      ({5{(in[12]  & (&(~(in[23:13]))))}} & 5'd11) |
 		                      ({5{(in[11]  & (&(~(in[23:12]))))}} & 5'd12) |
 		                      ({5{(in[10]  & (&(~(in[23:11]))))}} & 5'd13) |
 		                      ({5{(in[9]   & (&(~(in[23:10]))))}} & 5'd14) |
 		                      ({5{(in[8]   & (&(~(in[23: 9]))))}} & 5'd15) |
 		                      ({5{(in[7]   & (&(~(in[23: 8]))))}} & 5'd16) |
 		                      ({5{(in[6]   & (&(~(in[23: 7]))))}} & 5'd17) |
 		                      ({5{(in[5]   & (&(~(in[23: 6]))))}} & 5'd18) |
 		                      ({5{(in[4]   & (&(~(in[23: 5]))))}} & 5'd19) |
 		                      ({5{(in[3]   & (&(~(in[23: 4]))))}} & 5'd20) |
 		                      ({5{(in[2]   & (&(~(in[23: 3]))))}} & 5'd21) |
 		                      ({5{(in[1]   & (&(~(in[23: 2]))))}} & 5'd22) |
 		                      ({5{(in[0]   & (&(~(in[23: 1]))))}} & 5'd23);

endmodule


module leading_ones 
(
  input  wire [31:0] in,
  output wire [4:0] out
);

assign out [4:0]        = ({5{(in[31])}}    				         & 5'd31) |
                          ({5{(in[30] & (&(~(in[31]))))}}    & 5'd30) |
                          ({5{(in[29] & (&(~(in[31:30]))))}} & 5'd29) |
                          ({5{(in[28] & (&(~(in[31:29]))))}} & 5'd28) |
                          ({5{(in[27] & (&(~(in[31:28]))))}} & 5'd27) |
                          ({5{(in[26] & (&(~(in[31:27]))))}} & 5'd26) |
                          ({5{(in[25] & (&(~(in[31:26]))))}} & 5'd25) |
                          ({5{(in[24] & (&(~(in[31:25]))))}} & 5'd24) |
                          ({5{(in[23] & (&(~(in[31:24]))))}} & 5'd23) |
                          ({5{(in[22] & (&(~(in[31:23]))))}} & 5'd22) |
                          ({5{(in[21] & (&(~(in[31:22]))))}} & 5'd21) |
                          ({5{(in[20] & (&(~(in[31:21]))))}} & 5'd20) |
                          ({5{(in[19] & (&(~(in[31:20]))))}} & 5'd19) |
                          ({5{(in[18] & (&(~(in[31:19]))))}} & 5'd18) |
                          ({5{(in[17] & (&(~(in[31:18]))))}} & 5'd17) |
                          ({5{(in[16] & (&(~(in[31:17]))))}} & 5'd16) |
                          ({5{(in[15] & (&(~(in[31:16]))))}} & 5'd15) |
                          ({5{(in[14] & (&(~(in[31:15]))))}} & 5'd14) |
                          ({5{(in[13] & (&(~(in[31:14]))))}} & 5'd13) |
                          ({5{(in[12] & (&(~(in[31:13]))))}} & 5'd12) |
                          ({5{(in[11] & (&(~(in[31:12]))))}} & 5'd11) |
                          ({5{(in[10] & (&(~(in[31:11]))))}} & 5'd10) |
                          ({5{(in[9]  & (&(~(in[31:10]))))}} & 5'd9)  |
                          ({5{(in[8]  & (&(~(in[31:9]))))}} & 5'd8)   |
                          ({5{(in[7]  & (&(~(in[31:8]))))}} & 5'd7)   |
                          ({5{(in[6]  & (&(~(in[31:7]))))}} & 5'd6)   |
                          ({5{(in[5]  & (&(~(in[31:6]))))}} & 5'd5)   |
                          ({5{(in[4]  & (&(~(in[31:5]))))}} & 5'd4)   |
                          ({5{(in[3]  & (&(~(in[31:4]))))}} & 5'd3)   |
                          ({5{(in[2]  & (&(~(in[31:3]))))}} & 5'd2)   |
                          ({5{(in[1]  & (&(~(in[31:2]))))}} & 5'd1)   |
                          ({5{(in[0]  & (&(~(in[31:1]))))}} & 5'd0);          
endmodule       

module left_shifter #(parameter mant = 24) 
(
	input  wire [mant-1:0] mantisa,
	input  wire [7:0] shift_amount,

	output wire [mant-1:0] out
);

	wire [mant-1:0] temp;

	assign temp  = mantisa << shift_amount;
	assign out   = {temp[mant-1:1], mantisa[0]};

endmodule

module right_shifter 
(
  input  wire [26:0] mantisa,
  input  wire [7:0] shift_amount,

  output wire [26:0] out
);

  assign out = ({27{(shift_amount[7:0]==8'd0)}}  &         mantisa)                          |
              ({27{(shift_amount[7:0]==8'd1)}}  & {1'd0,  mantisa[26:2],   |mantisa[1:0]})  |
              ({27{(shift_amount[7:0]==8'd2)}}  & {2'd0,  mantisa[26:3],   |mantisa[2:0]})  |
              ({27{(shift_amount[7:0]==8'd3)}}  & {3'd0,  mantisa[26:4],   |mantisa[3:0]})  |
              ({27{(shift_amount[7:0]==8'd4)}}  & {4'd0,  mantisa[26:5],   |mantisa[4:0]})  |
              ({27{(shift_amount[7:0]==8'd5)}}  & {5'd0,  mantisa[26:6],   |mantisa[5:0]})  |
              ({27{(shift_amount[7:0]==8'd6)}}  & {6'd0,  mantisa[26:7],   |mantisa[6:0]})  |
              ({27{(shift_amount[7:0]==8'd7)}}  & {7'd0,  mantisa[26:8],   |mantisa[7:0]})  |
              ({27{(shift_amount[7:0]==8'd8)}}  & {8'd0,  mantisa[26:9],   |mantisa[8:0]})  |
              ({27{(shift_amount[7:0]==8'd9)}}  & {9'd0,  mantisa[26:10],  |mantisa[9:0]})  |
              ({27{(shift_amount[7:0]==8'd10)}} & {10'd0, mantisa[26:11],  |mantisa[10:0]}) |
              ({27{(shift_amount[7:0]==8'd11)}} & {11'd0, mantisa[26:12],  |mantisa[11:0]}) |
              ({27{(shift_amount[7:0]==8'd12)}} & {12'd0, mantisa[26:13],  |mantisa[12:0]}) |
              ({27{(shift_amount[7:0]==8'd13)}} & {13'd0, mantisa[26:14],  |mantisa[13:0]}) |
              ({27{(shift_amount[7:0]==8'd14)}} & {14'd0, mantisa[26:15],  |mantisa[14:0]}) |
              ({27{(shift_amount[7:0]==8'd15)}} & {15'd0, mantisa[26:16],  |mantisa[15:0]}) |
              ({27{(shift_amount[7:0]==8'd16)}} & {16'd0, mantisa[26:17],  |mantisa[16:0]}) |
              ({27{(shift_amount[7:0]==8'd17)}} & {17'd0, mantisa[26:18],  |mantisa[17:0]}) |
              ({27{(shift_amount[7:0]==8'd18)}} & {18'd0, mantisa[26:19],  |mantisa[18:0]}) |
              ({27{(shift_amount[7:0]==8'd19)}} & {19'd0, mantisa[26:20],  |mantisa[19:0]}) |
              ({27{(shift_amount[7:0]==8'd20)}} & {20'd0, mantisa[26:21],  |mantisa[20:0]}) |
              ({27{(shift_amount[7:0]==8'd21)}} & {21'd0, mantisa[26:22],  |mantisa[21:0]}) |
              ({27{(shift_amount[7:0]==8'd22)}} & {22'd0, mantisa[26:23],  |mantisa[22:0]}) |
              ({27{(shift_amount[7:0]==8'd23)}} & {23'd0, mantisa[26:24],  |mantisa[23:0]}) |
              ({27{(shift_amount[7:0]==8'd24)}} & {24'd0, mantisa[26:25],  |mantisa[24:0]}) |
              ({27{(shift_amount[7:0]==8'd25)}} & {25'd0, mantisa[26],     |mantisa[25:0]}) |
              ({27{(shift_amount[7:0]>=8'd26)}} & {26'd0,                  |mantisa[26:0]});
endmodule

module int_excep #(parameter width = 1)
(
  input  wire signed_out,
  input  wire is_qNaN,
  input  wire is_sNaN,
  input  wire sign,
  
  output wire [(width - 1):0] execp_out
);
  wire  max_int;
  
  assign max_int      = is_qNaN || is_sNaN || !sign;
  assign execp_out    = {signed_out ^ max_int, {(width - 1){max_int}}};

endmodule

module rvdff #( parameter WIDTH=1, SHORT=0 )
   ( input wire [(WIDTH-1):0] din,
     input wire           clk,
     input wire                   rst_l,

     output reg [(WIDTH-1):0] dout
     );

if (SHORT == 1) begin
   assign dout = din;
end
else begin
`ifdef RV_CLOCKGATE
   always @(posedge tb_top.clk) begin
      #0 $strobe("CG: %0t %m din %x dout %x clk %b width %d",$time,din,dout,clk,WIDTH);
   end
`endif

   always @(posedge clk or negedge rst_l) begin
      if (rst_l == 0)
        dout[WIDTH-1:0] <= 0;
      else
        dout[WIDTH-1:0] <= din[WIDTH-1:0];
   end

end
endmodule

module rvdffe #( parameter WIDTH=1, SHORT=0, OVERRIDE=0 )
   (
     input  wire [WIDTH-1:0] din,
     input  wire           en,
     input  wire           clk,
     input  wire           rst_l,
     output wire [WIDTH-1:0] dout
     );

   wire          [WIDTH-1:0] in;

if (SHORT == 1) begin : genblock
   if (1) begin : genblock
      assign dout = din;
   end
end
else begin : genblock

// `ifndef RV_PHYSICAL
//    if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
// `endif

			assign in = en ? din : dout;

      rvdff #(WIDTH) dff (.din(in), .dout(dout), .rst_l(rst_l), .clk(clk));

// `ifndef RV_PHYSICAL
//    end
//    // else
//    //    $error("%m: rvdffe must be WIDTH >= 8");
// `endif
end // else: !if(SHORT == 1)

endmodule // rvdffe

module exponent #(parameter exp_width = 8, parameter mant_width = 24) 
(
  input  wire [(exp_width + mant_width - 1):0] in,
  output wire [(exp_width + mant_width):0] out
);

function integer clog2;
  input integer a;
  
  begin
      a = a - 1;
      for (clog2 = 0; a > 0; clog2 = clog2 + 1) a = a>>1;
  end

endfunction

  localparam norm_dist_width = clog2(mant_width);

  wire sign;
  wire exp_in_zero, is_special, mant_in_zero, is_zero;
  wire [(exp_width - 1):0] exp_in;
  wire [(mant_width - 2):0] mant_in, sbnorm_mant;
  wire [exp_width:0] exp_adjusted, exp;
  wire [(norm_dist_width - 1):0] norm_dist;

  assign {sign, exp_in, mant_in} = in;
  assign exp_in_zero = (exp_in == 0);
  assign mant_in_zero = (mant_in == 0);

  lead_zero_param#(mant_width - 1, norm_dist_width) countLeadingZeros(mant_in, norm_dist);

  assign sbnorm_mant  = (mant_in<<norm_dist)<<1;
  assign exp_adjusted = (exp_in_zero ? norm_dist ^ ((1<<(exp_width + 1)) - 1) : exp_in) + ((1<<(exp_width - 1)) | (exp_in_zero ? 2 : 1));
  assign is_zero      = exp_in_zero && mant_in_zero;
  assign is_special   = (exp_adjusted[exp_width:(exp_width - 1)] == 'b11);

  assign exp[exp_width:(exp_width - 2)] = is_special ? {2'b11, !mant_in_zero} : is_zero ? 3'b000 : exp_adjusted[exp_width:(exp_width - 2)];
  assign exp[(exp_width - 3):0]         = exp_adjusted;
  assign out                            = {sign, exp, exp_in_zero ? sbnorm_mant : mant_in};

endmodule

module invert#(parameter width = 1) 
(
  input  wire [(width - 1):0] in, 
  output wire [(width - 1):0] out
);
  genvar ix;
  generate
    for (ix = 0; ix < width; ix = ix + 1) begin :bt
      assign out[ix] = in[width - 1 - ix];
    end
  endgenerate

endmodule

module low_mask_hi_lo#( parameter in_width = 1, parameter top_bound = 1, parameter bottom_bound = 0 ) 
(
  input  wire [(in_width - 1):0] in,
  output wire [(top_bound - bottom_bound - 1):0] out
);
	localparam num_in_vals = 1<<in_width;
	wire signed [num_in_vals:0] c;
	wire [(top_bound - bottom_bound - 1):0] reverse_out;
	
	assign c[num_in_vals]         = 1;
	assign c[(num_in_vals - 1):0] = 0;
	assign reverse_out            = (c>>>in)>>(num_in_vals - top_bound);
	invert #(top_bound - bottom_bound) reverse_hi(reverse_out, out);
endmodule

module low_mask_lo_hi#( parameter in_width = 1, parameter top_bound = 0, parameter bottom_bound = 1) 
(
  input  wire [(in_width - 1):0] in,
  output wire [(bottom_bound - top_bound - 1):0] out
);

  localparam num_in_vals = 1<<in_width;
  wire signed [num_in_vals:0] c;
  wire [(bottom_bound - top_bound - 1):0] reverse_out;

  assign c[num_in_vals]         = 1;
  assign c[(num_in_vals - 1):0] = 0;
  assign reverse_out            = (c>>>~in)>>(top_bound + 1);
  invert #(bottom_bound - top_bound) reverse_lo(reverse_out, out);

endmodule

module compress_by2#(parameter in_width = 1) 
(
  input  wire [(in_width - 1):0]     in, 
  output wire [((in_width - 1)/2):0] out
);

	localparam bit_num_reduced = (in_width - 1)/2;
	
  genvar ix;
	generate
	  for (ix = 0; ix < bit_num_reduced; ix = ix + 1) begin :bt
	  	assign out[ix] = |in[(ix*2 + 1):ix*2];
	  end
	endgenerate

	assign out[bit_num_reduced] = |in[(in_width - 1):bit_num_reduced*2];
endmodule

module compress_by4#(parameter in_width = 1) 
(
  input  wire [(in_width - 1):0]     in, 
  output wire [(in_width - 1)/4:0]   out
);

  localparam bit_num_reduced = (in_width - 1)/4;
  genvar ix;
  generate
	for (ix = 0; ix < bit_num_reduced; ix = ix + 1) begin :bt
		assign out[ix] = |in[(ix*4 + 3):ix*4];
	end
	endgenerate
	
  assign out[bit_num_reduced] = |in[(in_width - 1):bit_num_reduced*4];
endmodule

module lead_zero_param#(parameter in_width = 1, parameter count_width = 1) 
(
  input  wire [(in_width - 1):0] in, 
  output wire [(count_width - 1):0] count
);

  wire [(in_width - 1):0] reverse_in;
  wire [in_width:0] one_least_reverse_in;
  
  invert #(in_width) reverse_num(in, reverse_in);
  assign one_least_reverse_in = {1'b1, reverse_in} & ({1'b0, ~reverse_in} + 1);

  genvar ix;
  generate
    for (ix = 0; ix <= in_width; ix = ix + 1) begin :bt
      wire  [(count_width - 1):0] count_so_far;
      if (ix == 0) begin
        assign count_so_far = 0;
      end 
      else begin
        assign count_so_far = bt[ix - 1].count_so_far | (one_least_reverse_in[ix] ? ix : 0);
      if (ix == in_width) 
      assign count = count_so_far;
      end
  end
  endgenerate
endmodule

module round_excep#( parameter in_exp_width = 8, parameter in_mant_width = 24, parameter out_exp_width = 8, 
															 parameter out_mant_width = 24, parameter options = 0 ) 
(
	input  wire invalid_excep,     
	input  wire infinite_excep,    
	input  wire in_is_NaN,
	input  wire in_is_inf,
	input  wire in_is_zero,
	input  wire in_sign,
	input  wire signed [(in_exp_width + 1):0] in_sexp,   
	input  wire [in_mant_width:0] in_mant,
	input  wire [2:0] round_mode,

	output wire [(out_exp_width + out_mant_width)-1:0] result,
	output wire [4:0] exceptions
);

function integer clog2;
  input integer a;
  
  begin
      a = a - 1;
      for (clog2 = 0; a > 0; clog2 = clog2 + 1) a = a>>1;
  end

endfunction

	localparam sigMSBitAlwaysZero 	= ((options & `flRoundOpt_sigMSBitAlwaysZero) != 0);
	localparam effectiveInSigWidth 	= sigMSBitAlwaysZero ? in_mant_width : in_mant_width + 1;
	localparam neverUnderflows 			= ((options & (`flRoundOpt_neverUnderflows | `flRoundOpt_subnormsAlwaysExact))!= 0) 
																		|| (in_exp_width < out_exp_width);
	localparam neverOverflows 			= ((options & `flRoundOpt_neverOverflows) != 0) || (in_exp_width < out_exp_width);
	localparam adjustedExpWidth 		= (in_exp_width < out_exp_width) ? out_exp_width + 1 : (in_exp_width == out_exp_width)? 
																		in_exp_width + 2 : in_exp_width + 3;
	localparam outNaNExp 						= 7<<(out_exp_width - 2);
	localparam outInfExp 						= 6<<(out_exp_width - 2);
	localparam outMaxFiniteExp 			= outInfExp - 1;
	localparam outMinNormExp 				= (1<<(out_exp_width - 1)) + 2;
	localparam outMinNonzeroExp 		= outMinNormExp - out_mant_width + 1;
	localparam [out_exp_width:0] min_norm_exp = (1<<(out_exp_width - 1)) + 2;
	localparam norm_dist_width 			= clog2(in_mant_width);

	wire roundmode_near_even, roundmode_min_mag, roundmode_min, roundmode_max, roundmode_max_mag, round_mag_up;
	wire is_out_NaN;
	wire signed [(adjustedExpWidth - 1):0] adjusted_sexp;
	wire [(out_mant_width + 2):0] adjusted_mant;
	wire notNaN_is_special_inf_out, common_case, overflow, underflow, inexact, sign_out;	
	wire overflow_round_magup, peg_min_nonzero_mag_out, peg_max_finite_mag_out, notNaN_is_inf_out;
	wire [out_exp_width:0] exp_out;	
	wire [(out_mant_width - 2):0] mant_out;
	wire [(out_exp_width+out_mant_width):0] out;
	wire is_NaN, is_inf, is_zero, sign_res, is_subnorm;
	wire signed [(out_exp_width+1):0] s_exp;
	wire [out_mant_width:0] mant;
	wire [(norm_dist_width - 1):0] subnorm_shift_dist;
	wire [(out_exp_width   - 1):0] exp_res;
	wire [(out_mant_width  - 2):0] mant_res;
	wire [out_exp_width:0] common_exp_out;
	wire [(out_mant_width - 2):0] common_mant_out;
	wire common_overflow, common_total_underflow, common_underflow;
	wire common_inexact;
	wire do_shift_mant_down1;

	assign roundmode_near_even = (round_mode == `round_near_even);
	assign roundmode_min_mag   = (round_mode == `round_minMag);
	assign roundmode_min       = (round_mode == `round_min);
	assign roundmode_max       = (round_mode == `round_max);
	assign roundmode_max_mag 	 = (round_mode == `round_near_maxMag);
	assign round_mag_up        = (roundmode_min && in_sign) || (roundmode_max && !in_sign);

	assign is_out_NaN 				 = invalid_excep || (!infinite_excep && in_is_NaN);
  assign adjusted_sexp 			 = in_sexp + ((1<<out_exp_width) - (1<<in_exp_width));

	assign adjusted_mant 	 = in_mant;
	
	assign do_shift_mant_down1 = sigMSBitAlwaysZero ? 0 : adjusted_mant[out_mant_width + 2];
 	
	generate
		if ( neverOverflows && neverUnderflows && (effectiveInSigWidth <= out_mant_width) )  begin
			assign common_exp_out 				= adjusted_sexp + do_shift_mant_down1;
			assign common_mant_out 				= do_shift_mant_down1 ? adjusted_mant>>3 : adjusted_mant>>2;
		end 
	else begin
	
	wire [(out_mant_width + 2):0] roundMask;
	
	if (neverUnderflows) begin
		assign roundMask = {do_shift_mant_down1, 2'b11};
	end 
	else begin
	wire [out_mant_width:0] roundMask_main;
	
	low_mask_lo_hi#(out_exp_width + 1,outMinNormExp-out_mant_width-1,outMinNormExp) lowmask_roundmask
																											( adjusted_sexp[out_exp_width:0], roundMask_main );
	assign roundMask = {roundMask_main | do_shift_mant_down1, 2'b11};
	end

	wire [(out_mant_width + 2):0] shifted_round_mask, round_pos_mask;
	wire round_pos_bit , any_round_extra, any_round, round_incr;
	
	assign shifted_round_mask = roundMask>>1;
	assign round_pos_mask     = ~shifted_round_mask & roundMask;
	assign round_pos_bit      = (|(adjusted_mant[(out_mant_width + 2):3] & round_pos_mask[(out_mant_width + 2):3])) || ((|(adjusted_mant[2:0] & round_pos_mask[2:0])));
	assign any_round_extra    = (|(adjusted_mant[(out_mant_width + 2):3] & shifted_round_mask[(out_mant_width + 2):3])) || ((|(adjusted_mant[2:0] & shifted_round_mask[2:0])));
	assign any_round          = round_pos_bit || any_round_extra;

	wire [(out_mant_width + 1):0] rounded_mant;
	wire signed [adjustedExpWidth:0] sext_adjusted_exp,s_rounded_exp;
	
	assign round_incr 			 = ((roundmode_near_even || roundmode_max_mag) && round_pos_bit) || (round_mag_up && any_round);
	assign rounded_mant      = round_incr ? (((adjusted_mant | roundMask)>>2) + 1) & ~(roundmode_near_even && round_pos_bit && !any_round_extra
														 ? roundMask>>1 : 0) : (adjusted_mant & ~roundMask)>>2;
	assign sext_adjusted_exp = adjusted_sexp;
	assign s_rounded_exp     = sext_adjusted_exp + (rounded_mant>>out_mant_width);


	assign common_exp_out 	      = s_rounded_exp;
	assign common_mant_out 	      = do_shift_mant_down1 ? rounded_mant>>1 : rounded_mant;
	assign common_overflow 	      = neverOverflows ? 0 : (s_rounded_exp>>>(out_exp_width - 1) >= 3);
	assign common_total_underflow = neverUnderflows ? 0 : (s_rounded_exp < outMinNonzeroExp);

	wire unbound_range_round_posbit, unbound_range_any_round, unbound_range_round_incr, round_carry ;           

	assign unbound_range_round_posbit = do_shift_mant_down1 ? adjusted_mant[2] : adjusted_mant[1];
	assign unbound_range_any_round    = (do_shift_mant_down1 && adjusted_mant[2]) || (|adjusted_mant[1:0]);
	assign unbound_range_round_incr   = ((roundmode_near_even || roundmode_max_mag) && unbound_range_round_posbit) 
																			|| (round_mag_up && unbound_range_any_round);

	assign round_carry                = do_shift_mant_down1 ? rounded_mant[out_mant_width + 1] : rounded_mant[out_mant_width];
	assign common_underflow 					= neverUnderflows ? 0 : common_total_underflow || (any_round && (adjusted_sexp>>>out_exp_width <= 0) 
																			&& (do_shift_mant_down1 ? roundMask[3] : roundMask[2]) && !(((`flControl_tininessAfterRounding) != 0) 
																			&& !(do_shift_mant_down1 ? roundMask[4] : roundMask[3]) && round_carry && round_pos_bit 
																			&& unbound_range_round_incr));
	assign common_inexact 						= common_total_underflow || any_round;
	end
	endgenerate   
	
	assign notNaN_is_special_inf_out = infinite_excep || in_is_inf;
	assign common_case               = !is_out_NaN && !notNaN_is_special_inf_out && !in_is_zero;
	assign overflow                  = common_case && common_overflow;
	assign underflow                 = common_case && common_underflow;
	assign inexact                   = overflow || (common_case && common_inexact);

	assign overflow_round_magup 		 = roundmode_near_even || roundmode_max_mag || round_mag_up;
	assign peg_min_nonzero_mag_out   = common_case && common_total_underflow && (round_mag_up);
	assign peg_max_finite_mag_out  	 = overflow && !overflow_round_magup;
	assign notNaN_is_inf_out     		 = notNaN_is_special_inf_out || (overflow && overflow_round_magup);

	assign sign_out 								 = is_out_NaN ? `HardFloat_signDefaultNaN : in_sign;

	assign exp_out 	= (common_exp_out & ~(in_is_zero || common_total_underflow ? 7<<(out_exp_width - 2) : 0)
									   & ~(peg_min_nonzero_mag_out ? ~outMinNonzeroExp    : 0)
									   & ~(peg_max_finite_mag_out  ? 1<<(out_exp_width - 1) : 0)
									   & ~(notNaN_is_inf_out       ? 1<<(out_exp_width - 2) : 0))
									   | (peg_min_nonzero_mag_out  ? outMinNonzeroExp : 0)
									   | (peg_max_finite_mag_out   ? outMaxFiniteExp  : 0)
									   | (notNaN_is_inf_out        ? outInfExp        : 0)
									   | (is_out_NaN               ? outNaNExp        : 0);


	assign mant_out = (is_out_NaN ? `HardFloat_fractDefaultNaN(out_mant_width) : 0) 
										| (!in_is_zero && !common_total_underflow 
										? common_mant_out & `HardFloat_fractDefaultNaN(out_mant_width) : 0)
										| (!is_out_NaN && !in_is_zero && !common_total_underflow
										? common_mant_out & ~`HardFloat_fractDefaultNaN(out_mant_width): 0)
										| {(out_mant_width - 1){peg_max_finite_mag_out}};


	assign out 				= {sign_out, exp_out, mant_out};
	assign exceptions = {invalid_excep, infinite_excep, overflow, underflow, inexact};

	mac_spec_check #(out_exp_width, out_mant_width) mac_spec_check_out(.in(out), .is_qNaN(is_NaN), .is_inf(is_inf), .is_zero(is_zero), 
																																	   .is_sNaN(), .sign(sign_res), .s_exp(s_exp), .sig(mant));
	assign is_subnorm = (s_exp < min_norm_exp);

 	assign subnorm_shift_dist = min_norm_exp - 1 - s_exp;
 	assign exp_res  					= (is_subnorm ? 0 : s_exp - min_norm_exp + 1) | (is_NaN || is_inf ? {out_exp_width{1'b1}} : 0);
 	assign mant_res 					= is_subnorm ? (mant>>1)>>subnorm_shift_dist : is_inf ? 0 : mant;
 	assign result 						= {sign_res, exp_res, mant_res};

endmodule
