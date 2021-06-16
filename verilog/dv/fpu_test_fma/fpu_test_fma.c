/* SPDX-FileCopyrightText: 2020 Efabless Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */
// This include is relative to $CARAVEL_PATH (see Makefile)
#include "verilog/dv/caravel/defs.h"
#include "../verilog/dv/dv_defs.h"
#include "verilog/dv/caravel/stub.c"
/*
    Wishbone Test:
        - Configures MPRJ lower 8-IO pins as outputs
        - Checks counter value through the wishbone port
*/
int i = 0;
int clk = 0;
void main()
{
   // volatile unit32_t *base_address;
    /*
    IO Control Registers
    | DM     | VTRIP | SLOW  | AN_POL | AN_SEL | AN_EN | MOD_SEL | INP_DIS | HOLDH | OEB_N | MGMT_EN |
    | 3-bits | 1-bit | 1-bit | 1-bit  | 1-bit  | 1-bit | 1-bit   | 1-bit   | 1-bit | 1-bit | 1-bit   |
    Output: 0000_0110_0000_1110  (0x1808) = GPIO_MODE_USER_STD_OUTPUT
    | DM     | VTRIP | SLOW  | AN_POL | AN_SEL | AN_EN | MOD_SEL | INP_DIS | HOLDH | OEB_N | MGMT_EN |
    | 110    | 0     | 0     | 0      | 0      | 0     | 0       | 1       | 0     | 0     | 0       |
    Input: 0000_0001_0000_1111 (0x0402) = GPIO_MODE_USER_STD_INPUT_NOPULL
    | DM     | VTRIP | SLOW  | AN_POL | AN_SEL | AN_EN | MOD_SEL | INP_DIS | HOLDH | OEB_N | MGMT_EN |
    | 001    | 0     | 0     | 0      | 0      | 0     | 0       | 0       | 0     | 1     | 0       |
    */
    /* Set up the housekeeping SPI to be connected internally so    */
    /* that external pin changes don't affect it.           */
    reg_spimaster_config = 0xa002;  // Enable, prescaler = 2,
                                        // connect to housekeeping SPI
    // Connect the housekeeping SPI to the SPI master
    // so that the CSB line is not left floating.  This allows
    // all of the GPIO pins to be used for user functions.
    reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_29 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_28 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_27 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_26 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_25 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_24 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_23 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_22 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_21 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_20 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_19 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_18 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_17 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;
     /* Apply configuration */
    reg_mprj_xfer = 1;
    while (reg_mprj_xfer == 1);
    reg_la2_oenb = reg_la2_iena = 0xFFFFFFFF;    // [95:64]
    
    // Flag start of the test1
    reg_mprj_datal = 0xAB600000;

    //writing into input csrs
	ups_operand_a 	    = 0x00000001;
	ups_operand_b 	    = 0x00000002;
	ups_operand_c 	    = 0x00000003;
	ups_frm		    = 0x00000003;
	ups_operation	    = 0b00000000000000000000010000000000;
	//expected_result     = 0x00000004;
    //expected_exception  = 0x00000003;

	//waiting for operation to be completed
	while (ups_interrupt_generation != 1); //waiting for the operation to be completed
	while (ups_operation_completed != 1024);

    while (ups_result != 0x00000004);
    while (ups_fflags != 0x00000003);
	
        reg_mprj_datal  = 0xAB610000; //flag end of test1

     // Flag start of the test2
    reg_mprj_datal = 0xAB600000;

	ups_operand_a 	    = 0x7f7fffff;
	ups_operand_b 	    = 0x00000002;
	ups_operand_c 	    = 0xf0000002;
	ups_frm		        = 0x00000001;
	ups_operation	    = 0b00000000000000000000010000000000;
	//expected_result     = 0xf0000001;
    //expected_exception  = 0x00000001;

    while (ups_interrupt_generation != 1);
	while (ups_operation_completed != 1024);
	
    while (ups_result != 0xf0000001);
    while (ups_fflags != 0x00000001); 

    reg_mprj_datal  = 0xAB610000;  //flag end of test2

         // Flag start of the test3
    reg_mprj_datal = 0xAB600000;

	ups_operand_a 	    = 0x76000000;
	ups_operand_b 	    = 0x7F700000;
	ups_operand_c 	    = 0x78000000;
	ups_frm		        = 0x00000000;
	ups_operation	    = 0b00000000000000000000010000000000;
	//expected_result     = 0x7f800000;
    //expected_exception  = 0x00000005;

	while (ups_interrupt_generation != 1);
    while (ups_operation_completed != 1024);
	
    while (ups_result != 0x7f800000);
    while (ups_fflags != 0x00000005);

    reg_mprj_datal  = 0xAB610000;  //flag end of test3
    reg_mprj_datal  = 0xAB620000; //flag end of all test to finish

}


