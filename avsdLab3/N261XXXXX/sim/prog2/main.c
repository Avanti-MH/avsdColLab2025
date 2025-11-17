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

int main(void) {
  extern unsigned char _binary_image_bmp_start;
	extern unsigned char _test_start;
	
	unsigned char byte_size0 = *(&_binary_image_bmp_start + 2);
	unsigned char byte_size1 = *(&_binary_image_bmp_start + 3);
	unsigned char byte_size2 = *(&_binary_image_bmp_start + 4);
	unsigned char byte_size3 = *(&_binary_image_bmp_start + 5);
	unsigned int bmp_byte_size = (byte_size3 << 24) + (byte_size2 << 16) + (byte_size1 << 8) + byte_size0;

	for (int i = 0; i < 54; i++)
		*(&_test_start + i) = *(&_binary_image_bmp_start + i);

	for (int i = 54; i < bmp_byte_size; i+=3) {
		unsigned char gray;
		if ((*(&_binary_image_bmp_start + i) == 0xff) && (*(&_binary_image_bmp_start + i + 1) == 0xff) && (*(&_binary_image_bmp_start + i + 2) == 0xff))
			gray = 0xff;
		else {
			unsigned char blue = *(&_binary_image_bmp_start + i);
			unsigned char green = *(&_binary_image_bmp_start + i + 1);
			unsigned char red = *(&_binary_image_bmp_start + i + 2);
			gray = ((blue * 11) + (green * 59) + (red * 30)) / 100;
		}
		*(&_test_start + i) = gray;
		*(&_test_start + i + 1) = gray;
		*(&_test_start + i + 2) = gray;
	}

	return 0;
}