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

extern unsigned char _test_start;
extern const unsigned char _binary_image_bmp_start;

typedef struct {
    uint16_t bfType;      // 'BM' (0x4D42)
    uint32_t bfSize;
    uint16_t bfReserved1;
    uint16_t bfReserved2;
    uint32_t bfOffBits;   // 位圖資料起始偏移
} __attribute__((packed)) BMPHeader;

typedef struct {
    uint32_t biSize;
    int32_t  biWidth;
    int32_t  biHeight;
    uint16_t biPlanes;
    uint16_t biBitCount;   // 24 表示 RGB888
    uint32_t biCompression;
    uint32_t biSizeImage;
    int32_t  biXPelsPerMeter;
    int32_t  biYPelsPerMeter;
    uint32_t biClrUsed;
    uint32_t biClrImportant;
} __attribute__((packed)) DIBHeader;

/* 使用整數運算的灰階轉換：gray = (R*77 + G*150 + B*29) >> 8 */
static void bmp_to_grayscale(uint8_t *bmp)
{
    BMPHeader *bh = (BMPHeader *)bmp;
    DIBHeader *dh = (DIBHeader *)(bmp + sizeof(BMPHeader));

    /* 驗證 BMP 格式與基本屬性 */
    if (bh->bfType          != 0x4D42)  return;         /* 檔頭錯誤 */
    if (dh->biBitCount      != 24)      return;         /* 僅支援 24-bit */
    if (dh->biCompression   != 0)       return;         /* 僅支援未壓縮 */

    uint32_t width  = (uint32_t)dh->biWidth;
    uint32_t height = (dh->biHeight > 0) ? (uint32_t)dh->biHeight : (uint32_t)(-dh->biHeight);
    uint32_t offset = bh->bfOffBits;

    for (int i = 0; i < offset; i++)
		*(&_test_start + i) = (unsigned char *)(&bmp + i);

    /* 每行對齊至4位元組邊界 */
    uint32_t rowSize = (width * 3 + 3) & ~3;

    /* BMP 可能是 bottom-up，因此逐行處理 */
    for (uint32_t y = 0; y < height; y++) {
        uint8_t *row = bmp + offset + y * rowSize;
        for (uint32_t x = 0; x < width; x++) {
            uint8_t *px = row + x * 3;
            uint8_t B = px[0];
            uint8_t G = px[1];
            uint8_t R = px[2];

            /* 整數近似灰階公式 */
            uint8_t gray = (uint8_t)((R * 77 + G * 150 + B * 29) >> 8);

            *(&_test_start + y * rowSize + x * 3 + 0) = (unsigned char)gray;
            *(&_test_start + y * rowSize + x * 3 + 1) = (unsigned char)gray;
            *(&_test_start + y * rowSize + x * 3 + 2) = (unsigned char)gray;
        }
    }
}

void process_embedded_bmp(void)
{
    /* 直接在圖片記憶體上修改（若放在可寫段） */
    uint8_t *bmp = (uint8_t *)_binary_image_bmp_start;
    bmp_to_grayscale(bmp);
}

int main(void) {
    process_embedded_bmp();
}
