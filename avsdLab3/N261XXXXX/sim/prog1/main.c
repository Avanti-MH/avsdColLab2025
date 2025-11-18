#include <stdint.h>

#define MIP_MEIP (1 << 11) // External interrupt pending
#define MIP_MTIP (1 << 7)  // Timer interrupt pending
#define MIP 0x344

volatile unsigned int *WDT_addr = (int *) 0x10010000;
volatile unsigned int *dma_addr_boot = (int *) 0x10020000;




void timer_interrupt_handler(void) {
  asm("csrsi mstatus, 0x0"); // MIE of mstatus
  WDT_addr[0x40] = 0; // WDT_en
  asm("j _start");
}

void external_interrupt_handler(void) {
    volatile unsigned int *dma_addr_boot = (int *) 0x10020000;
	asm("csrsi mstatus, 0x0"); // MIE of mstatus
	dma_addr_boot[0x40] = 0; // disable DMA
}

void trap_handler(void) {
    uint32_t mip;
    asm volatile("csrr %0, %1" : "=r"(mip) : "i"(MIP));
	
    if ((mip & MIP_MTIP) >> 7) {
        timer_interrupt_handler();
    }

    if ((mip & MIP_MEIP) >> 11) {
        external_interrupt_handler();
    }
}




int main (void) {
	extern int array_size;
	extern short array_addr;
	extern short _test_start;

	*(&_test_start) = *(&array_addr);

	for (int array_comp = 1; array_comp < array_size; array_comp++) {
		int insert = 0;
		for (int test_comp = 0; test_comp < array_comp; test_comp++) {
			if (*(&array_addr + array_comp) < *(&_test_start + test_comp)) {
				for (int i = array_comp; i > test_comp; i--) {
					*(&_test_start + i) = *(&_test_start + i - 1);
				}
				*(&_test_start + test_comp) = *(&array_addr + array_comp);
				insert = 1;
				break;
			}
		}
		if (insert == 0) *(&_test_start + array_comp) = *(&array_addr + array_comp);
	}
 
	return 0;
}

