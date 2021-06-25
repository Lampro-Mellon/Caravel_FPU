/*
 * SPDX-FileCopyrightText: 2020 Efabless Corporation
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

#include <stdint.h>
#include <stdbool.h>

#define ups_operand_a		            	(*(volatile uint32_t*)0x30000000)
#define ups_operand_b		            	(*(volatile uint32_t*)0x30000004)
#define ups_operand_c		            	(*(volatile uint32_t*)0x30000008)
#define ups_result     		            	(*(volatile uint32_t*)0x3000000c)
#define ups_operation_completed 		(*(volatile uint32_t*)0x30000010)
#define ups_interrupt_generation		(*(volatile uint32_t*)0x30000014)
#define ups_operation		            	(*(volatile uint32_t*)0x3000001c)
#define ups_fflags		                (*(volatile uint32_t*)0x30000020)
#define ups_frm		                    	(*(volatile uint32_t*)0x30000024)
#define ups_fcsr		                (*(volatile uint32_t*)0x30000028)
