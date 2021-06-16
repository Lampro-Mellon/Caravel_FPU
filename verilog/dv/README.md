<!---
# SPDX-FileCopyrightText: 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
-->


# User Project Example DV

The directory includes multiple tests for the FPU user-project example: 

### IO Ports Test 

* This test is meant to verify that we can configure the pads for the user project area. The firmware configures the lower 32 IO pads in the user space as outputs:

	```c
	reg_mprj_io_0 	=  GPIO_MODE_USER_STD_OUTPUT;
	reg_mprj_io_1 	=  GPIO_MODE_USER_STD_OUTPUT;
	.....
	reg_mprj_io_32 	=  GPIO_MODE_USER_STD_OUTPUT;
	```

* Then, the firmware applies the pad configuration by enabling the serial transfer on the shift register responsible for configuring the pads and waits until the transfer is done. 
	```c
	reg_mprj_xfer = 1;
	while (reg_mprj_xfer == 1);
	```

* The testbench success criteria is that we can observe the fpu_result output value on the lower 32 I/O pads. This criteria is checked by the testbench through observing the values on the I/O pads as follows: 

	```verilog
	wait(mprj_io == 32'h00000003); //(in our case result was 0x00000003)

	```

* If the testbench fails, it will print a timeout message to the terminal. 

### Logic Analyzer Test
 
* This test is meant to verify that we can use the logic analyzer to monitor and write signals in the user project from the management SoC. Firstly, the firmware configures the upper 16 of the first 32 GPIO pads as outputs from the managent SoC, applies the configuration by initiating the serial transfer on the shift register, and writes a value on the pads to indicate the end of pad configuration and the start of the test. 

	```c
	reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
	reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
	.....
	reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;

	reg_mprj_xfer = 1;
	while (reg_mprj_xfer == 1);

	// Flag start of the test 
	reg_mprj_datal = 0xAB600000;
	```
	
	This is done to flag the start/success/end of the simulation by writing a certain value to the I/Os which is then checked by the testbench to know whether the test started/ended/succeeded. For example, the testbench checks on the value of the upper 16 of 32 I/Os, if it is equal to `16'hAB60`, then we know that the test started.  

	```verilog
	wait(checkbits == 16'hAB60);
	$display("LA Test started");
	```
	
* Then, the firmware configures the logic analyzer (LA) probes `[31:0]` as inputs to the user project example to send the address value, and configure the logic analyzer probes `[63:32]` as outputs from the management SoC (inputs to the user_proj_example) to set the data value to that particular address set earlier. This is done by writing to the LA probes enable registers.   Note that the output enable is active low, while the input enable is active high.  Every channel can be configured for input, output, or both independently.

 
	```c
	reg_la0_oenb = reg_la0_iena = 0x00000000;    
	reg_la1_oenb = reg_la1_iena = 0x00000000;    
	```

 * In the user_proj_example RTL, the clock can either be supplied from the `wb_clk_i` or from the logic analyzer through bit `[64]`. Similarly, the reset signal can be supplied from the `wb_rst_i` or through `LA[65]`.  The firmware configures the clk and reset LA probes as outputs from the management SoC by writing to the LA2 enable register. 

	
	```c
	reg_la2_oenb  = reg_la2_iena = 0xFFFFFFFC; 	// Configure LA[64] LA[65] as outputs from the cpu
	```

* Then, the firmware supplies both clock reset signals through LA2 data register. First, both are set to one. Then, reset is driven to zero and the clock is toggled for 6 clock cycles and it writes the values to the input csrs of fpu at each clock cycle. And then disable probs as inputs to read the result value. 

	```c
	reg_la2_data = 0x00000003;	// Write one to LA[64] and LA[65]
	for (i=0; i<12; i=i+1) {   	// Toggle clk & de-assert reset
		clk = !clk;               	
		reg_la2_data = 0x00000000 | clk;
		if(i==0)
            {reg_la0_data = 0x30000000;
            reg_la1_data = 0x00000001; }
		...
		...
	}
	``` 

	```c
	
	reg_la0_oenb  = reg_la0_iena = 0xFFFFFFFF;     // Disable probes
	reg_la1_oenb  = reg_la1_iena = 0xFFFFFFFF;     // Disable probes
	```

* The firmware then checks the result value equal to 0x00000003 and flags the success of the test by writing `0xAB461` to pads 16 to 31.  The firmware reads the result value through the logic analyzer probes `[31:0]` 

	```c
	if (reg_la0_data == 0x00000003) {	     // Read current result value through LA
		reg_mprj_datal = 0xAB610000; // Flag success of the test
		break;
	}
	```

	```
	
### Wishbone Tests

* This test is meant to verify that we can read and write to the fpu registers through the wishbone port. The firmware writes a value to the input csrs which are operands and operation conntrol csr that controls which fpu operation to perform. Then it waits untill the interrupt csr value becomes 1 which indicates the completion of fpu operation. After completion of fpu operation final thing is to read the result and exception csr values and check whether it is according to the expected result depending upon the operaton. The read and write transactions happen through the management SoC wishbone bus and are initiated by either writing or reading from the user project address on the wishbone bus. These tests starting from fpu_test prefix use the same approach but they target different sub modules of FPU i.e.
  * fpu_test_add_sub 
  * ...
  * ...
  * fpu_test_sqrt

* The defines which target the user project example csrs are defined in dv_defs.h 
