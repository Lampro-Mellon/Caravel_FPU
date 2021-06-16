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

`default_nettype none

`timescale 1 ns / 1 ps
//`include "fpu.c"
`include "uprj_netlists.v"
`include "caravel_netlists.v"
`include "spiflash.v"

/*import "DPI-C" context function void fpu_c (input int a,b,c,roundingMode,
                                            input bit add_op,
                                            input int COMP_op,MAC_op,min_max_op,signed_conv,
                                            input int finalStage_valid,
                                            output int result,exceptionFlags                                          );*/

module fpu_test_min_max_tb;
	reg clock;
	reg RSTB;
	reg CSB;

	reg power1, power2;

    	wire gpio;
    	wire [37:0] mprj_io;
	wire [15:0] checkbits;

	assign checkbits = mprj_io[31:16];
	assign mprj_io[3] = (CSB == 1'b1) ? 1'b1 : 1'bz;

	always #12.5 clock <= (clock === 1'b0);

	initial begin
		clock = 0;
	end

	initial begin
		$dumpfile("fpu_test_min_max.vcd");
		$dumpvars(0, fpu_test_min_max_tb);

		// Repeat cycles of 1000 clock edges as needed to complete testbench
		repeat (30) begin
			repeat (1000) @(posedge clock);
			// $display("+1000 cycles");
		end
		$display("%c[1;31m",27);
		`ifdef GL
			$display ("Monitor: Timeout, Test Mega-Project IO (GL) Failed");
		`else
			$display ("Monitor: Timeout, Test Mega-Project IO (RTL) Failed");
		`endif
		$display("%c[0m",27);
		$finish;
	end
	reg [32:0]i=1;
	initial begin
		fork begin
			forever begin
				wait(checkbits == 16'h AB60) begin
					$display("Monitor: Test %0d Started",i);
					fork
						wait(uut.mprj.mprj.wbs_adr_i == 32'h30000000) begin//operand a			
							repeat(2)@(negedge uut.mprj.mprj.wb_clk_i);
							if(uut.mprj.mprj.wbs_dat_i != uut.mprj.mprj.fpu.a)
								$display("\na NOT CORRECT \ntime = %0d\tactual = 32'h%0h\ expected = 32'h%0h",$time,uut.mprj.mprj.wbs_dat_i,uut.mprj.mprj.fpu.a);
							else
								$display("\ntime = %0d \n a is correct\n",$time);
						end
						wait(uut.mprj.mprj.wbs_adr_i == 32'h30000004) begin//operand b			
							repeat(2)@(negedge uut.mprj.mprj.wb_clk_i);
							if(uut.mprj.mprj.wbs_dat_i != uut.mprj.mprj.fpu.b)
								$display("\nb NOT CORRECT \ntime = %0d\tactual = 32'h%0h\ expected = 32'h%0h",$time,uut.mprj.mprj.wbs_dat_i,uut.mprj.mprj.fpu.b);
							else
								$display("\ntime = %0d \n b is correct\n",$time);
						end

						wait(uut.mprj.mprj.wbs_adr_i == 32'h30000024) begin//operand rm			
							repeat(2)@(negedge uut.mprj.mprj.wb_clk_i);
							if(uut.mprj.mprj.wbs_dat_i != uut.mprj.mprj.fpu.round_mode)
								$display("\nrm NOT CORRECT \ntime = %0d\tactual = 32'h%0h\ expected = 32'h%0h",$time,uut.mprj.mprj.wbs_dat_i,uut.mprj.mprj.fpu.round_mode);
							else
								$display("\ntime = %0d \n rm is correct\n",$time);
						end
						wait(uut.mprj.mprj.wbs_adr_i == 32'h3000001c) begin //operand operation			
							repeat(2)@(negedge uut.mprj.mprj.wb_clk_i);
							if(uut.mprj.mprj.wbs_dat_i != {19'b0,uut.mprj.mprj.fpu.valid_in,uut.mprj.mprj.fpu.op_in})
								$display("\noperation NOT CORRECT \ntime = %0d\tactual = 32'h%0h\ expected = 32'h%0h",$time,uut.mprj.mprj.wbs_dat_i,{19'b0,uut.mprj.mprj.fpu.valid_in, uut.mprj.mprj.fpu.op_in});
							else
								$display("\ntime = %0d \n operation is correct\n",$time	);
						end
					join
						wait(checkbits == 16'h AB61) begin
							$display("Monitor: Test %0d Passed\n",i);
							i = i+1;
						end
				end
			end
		end
		begin
			wait(checkbits == 16'h AB62)
			begin
				$display("Monitor: ALL Test Finished");
				$finish;
				//disable fork;
			end
		end
		join

	end


	initial begin
		RSTB <= 1'b0;
		CSB  <= 1'b1;		// Force CSB high
		#2000;
		RSTB <= 1'b1;	    	// Release reset
		#170000;
		CSB = 1'b0;		// CSB can be released
	end

	initial begin		// Power-up sequence
		power1 <= 1'b0;
		power2 <= 1'b0;
		#200;
		power1 <= 1'b1;
		#200;
		power2 <= 1'b1;
	end

    	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;

	wire VDD1V8;
    	wire VDD3V3;
	wire VSS;
    
	assign VDD3V3 = power1;
	assign VDD1V8 = power2;
	assign VSS = 1'b0;

	caravel uut (
		.vddio	  (VDD3V3),
		.vssio	  (VSS),
		.vdda	  (VDD3V3),
		.vssa	  (VSS),
		.vccd	  (VDD1V8),
		.vssd	  (VSS),
		.vdda1    (VDD3V3),
		.vdda2    (VDD3V3),
		.vssa1	  (VSS),
		.vssa2	  (VSS),
		.vccd1	  (VDD1V8),
		.vccd2	  (VDD1V8),
		.vssd1	  (VSS),
		.vssd2	  (VSS),
		.clock	  (clock),
		.gpio     (gpio),
        	.mprj_io  (mprj_io),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.resetb	  (RSTB)
	);

	spiflash #(
		.FILENAME("fpu_test_min_max.hex")
	) spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(),
		.io3()
	);

endmodule
`default_nettype wire
