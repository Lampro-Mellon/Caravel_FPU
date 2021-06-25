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

module fpu_registers(
    input  wire         clk,
    input  wire         rst_l,
    input  wire  [31:0] fpu_result,
    input  wire  [12:0] fpu_valids,
    input  wire  [31:0] addr,
    input  wire         wren,
    input  wire  [31:0] wrdata,
    input  wire  [4:0]  exceptions,

    output wire         ack,
    output wire  [31:0] rddata,
    output wire  [31:0] opA,
    output wire  [31:0] opB,
    output wire  [31:0] opC,
    output wire  [2:0]  frm,

    output wire [12:0] op_valids,
    output wire [31:0] result
);

   localparam base_addr = 32'h3000_0000;

   wire fpu_result_valid;

   assign fpu_result_valid = |fpu_valids[12:2];
    
   // ----------------------------------------------------------------------
   // OPERAND_A (RW)
   //  [31:0]   OPERAND_A
   localparam OPERAND_A = base_addr + 8'h00;

   wire        addr_A;
   wire        wr_opA;
   wire [31:0] opA_ns;

   assign addr_A = (addr[31:0] == OPERAND_A);
   assign wr_opA = wren && addr_A;
   assign opA_ns = wrdata;

   rvdffe #(32) opA_ff (.clk(clk), .rst_l(rst_l), .en(wr_opA), .din(opA_ns), .dout(opA));


   // ----------------------------------------------------------------------
   // OPERAND_B (RW)
   //  [31:0]   OPERAND_B
   localparam OPERAND_B = base_addr + 8'h04;

   wire        addr_B;
   wire        wr_opB;
   wire [31:0] opB_ns;

   assign addr_B = (addr[31:0] == OPERAND_B);
   assign wr_opB = wren && addr_B;
   assign opB_ns = wrdata;

   rvdffe #(32) opB_ff (.clk(clk), .rst_l(rst_l), .en(wr_opB), .din(opB_ns), .dout(opB));


   // ----------------------------------------------------------------------
   // OPERAND_C (RW)
   //  [31:0]   OPERAND_C
   localparam OPERAND_C = base_addr + 8'h08;

   wire        addr_C;
   wire        wr_opC;
   wire [31:0] opC_ns;

   assign addr_C = (addr[31:0] == OPERAND_C);
   assign wr_opC = wren && addr_C;
   assign opC_ns = wrdata;

   rvdffe #(32) opC_ff (.clk(clk), .rst_l(rst_l), .en(wr_opC), .din(opC_ns), .dout(opC));


   // ----------------------------------------------------------------------
   // RESULT (RW)
   //  [31:0]   RESULT
   localparam RESULT = base_addr + 8'h0C;

   wire        addr_result;
   wire        wr_result;
   wire [31:0] result_ns;

   assign addr_result = (addr[31:0] == RESULT);
   assign wr_result   = fpu_result_valid;
   assign result_ns   = fpu_result;

   rvdffe #(32) result_ff (.clk(clk), .rst_l(rst_l), .en(wr_result), .din(result_ns), .dout(result));


   // ----------------------------------------------------------------------
   // OPERATION_COMPLETED (RW)
   //  [1:0]   op
   //  [14:2]  operation_in_flight
   //  [31:15] reserved
   localparam OPERATION_COMPLETED = base_addr + 8'h10;

   wire        addr_op_comp;
   wire        wr_op_comp;
   wire [12:0] op_comp_ns;
   wire [12:0] op_comp;

   assign addr_op_comp = (addr[31:0] == OPERATION_COMPLETED);
   assign wr_op_comp   = fpu_result_valid;
   assign op_comp_ns   = fpu_valids;

   rvdffe #(13) op_comp_ff (.clk(clk), .rst_l(rst_l), .en(wr_op_comp), .din(op_comp_ns), .dout(op_comp));


   // ----------------------------------------------------------------------
   // INTERRUPT_GENERATION (RC)
   //  [0]     operation done
   //  [31:1]  reserved
   localparam INTERRUPT_GENERATION = base_addr + 8'h14;

   wire        addr_intr_gen;
   wire        wr_intr_gen;
   wire        intr_gen_ns;
   wire        inter_gen;

   assign addr_intr_gen = (addr[31:0] == INTERRUPT_GENERATION);
   assign wr_intr_gen   = (addr_intr_gen && !wren) || fpu_result_valid;
   assign intr_gen_ns   = (addr_intr_gen && !wren) ? 1'b0 : (fpu_result_valid ? 1'b1 : inter_gen);

   rvdffe #(1) intr_gen_ff (.clk(clk), .rst_l(rst_l), .en(wr_intr_gen), .din(intr_gen_ns), .dout(inter_gen));
   

   // ----------------------------------------------------------------------
   // OPERATION (RW)
   //  [1:0]   op
   //  [14:2]  operation_in_flight
   //  [31:15] reserved
   localparam OPERATION = base_addr + 8'h1C;

   wire        addr_op;
   wire        wr_op;
   wire [12:0] op_ns;

   assign addr_op = (addr[31:0] == OPERATION);
   assign wr_op   = |op_valids | (addr_op && wren);
   assign op_ns   = |op_valids ? 13'b0 : wrdata;

   rvdffe #(13) op_ff (.clk(clk), .rst_l(rst_l), .en(wr_op), .din(op_ns), .dout(op_valids));


   // ----------------------------------------------------------------------
   // FCSR (RW)
   //  [7:5]   frm     - rounding mode
   //  [4:0]   fflags  - accrued exceptions
   localparam FFLAGS = base_addr + 8'h20;
   localparam FRM    = base_addr + 8'h24;
   localparam FCSR   = base_addr + 8'h28;

   wire  [4:0] fflags;
   wire  [4:0] fflags_ns;
   wire  [2:0] frm_ns;
   wire  [7:0] fcsr_read;
   wire        frm_addr;
   wire        fflags_addr;
   wire        fcsr_addr;
   wire				 wr_fflags_r;
   wire				 wr_frm_r;
   wire				 wr_fcsr_r;   

   assign frm_addr    = (addr == FRM);
   assign fflags_addr = (addr == FFLAGS);
   assign fcsr_addr   = (addr == FCSR);
   assign wr_fflags_r = wren && fflags_addr;
   assign wr_frm_r    = wren && frm_addr;
   assign wr_fcsr_r   = wren && fcsr_addr;

   assign fflags_ns   = fpu_result_valid ? exceptions[4:0] : wrdata;
   assign frm_ns      = frm_addr ? wrdata[2:0] : wrdata[7:5];

   rvdffe #(5)  fflags_ff (.clk(clk), .rst_l(rst_l), .en(wr_fflags_r | wr_fcsr_r | fpu_result_valid), .din(fflags_ns[4:0]), .dout(fflags[4:0]));
   rvdffe #(3)  frm_ff    (.clk(clk), .rst_l(rst_l), .en(wr_frm_r    | wr_fcsr_r), .din(frm_ns[2:0]),    .dout(frm[2:0]));

   assign fcsr_read = {frm, fflags};

   assign rddata    = ({32{addr_A}}        & opA)                |
                      ({32{addr_B}}        & opB)                |
                      ({32{addr_C}}        & opC)                |
                      ({32{addr_result}}   & result)             |
                      ({32{addr_op_comp}}  & {19'b0, op_comp})   |
                      ({32{addr_intr_gen}} & {31'b0, inter_gen}) |
                      ({32{addr_op}}       & {19'b0, op_valids}) |
                      ({32{frm_addr}}      & {29'b0, frm})       |
                      ({32{fflags_addr}}   & {27'b0, fflags})    |
                      ({32{fcsr_addr}}     & {24'b0, fcsr_read});

    assign ack = inter_gen | (addr == OPERAND_A) | (addr == OPERAND_B) | (addr == OPERAND_C) | (addr == OPERATION) | 
                 (addr == FFLAGS) | (addr == FRM) | (addr == FCSR) | (addr == OPERATION_COMPLETED) | (addr == RESULT);

endmodule
