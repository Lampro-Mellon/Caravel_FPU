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
