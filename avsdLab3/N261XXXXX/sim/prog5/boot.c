void boot() {
    extern unsigned int _dram_i_start;
    extern unsigned int _dram_i_end;
    extern unsigned int _imem_start;

    extern unsigned int __sdata_start;
    extern unsigned int __sdata_end;
    extern unsigned int __sdata_paddr_start;

    extern unsigned int __data_start;
    extern unsigned int __data_end;
    extern unsigned int __data_paddr_start;

    // DMA registers
    volatile unsigned int *dma_en   = (unsigned int *) 0x10020100; // DMAEN
    volatile unsigned int *dma_desc = (unsigned int *) 0x10020200; // Base address register for descriptor list (assumed)

    // Descriptor structure in DM (0x0002_FF00 ~ 0x0002_FFFF)
    typedef struct {
      unsigned int DMASRC;
      unsigned int DMADST;
      unsigned int DMALEN;
      unsigned int NEXT_DESC;
      unsigned int EOC;
    } DMA_DESC;

    volatile DMA_DESC *desc_list = (DMA_DESC *)0x0002FF00;

    // -------- Descriptor 0: IMEM load --------
    desc_list[0].DMASRC = (unsigned int)&_dram_i_start;
    desc_list[0].DMADST = (unsigned int)&_imem_start;
    desc_list[0].DMALEN = (unsigned int)(&_dram_i_end - &_dram_i_start + 1);
    desc_list[0].NEXT_DESC = (unsigned int)&desc_list[1];
    desc_list[0].EOC = 0;

    // -------- Descriptor 1: DATA segment --------
    desc_list[1].DMASRC = (unsigned int)&__data_paddr_start;
    desc_list[1].DMADST = (unsigned int)&__data_start;
    desc_list[1].DMALEN = (unsigned int)(&__data_end - &__data_start + 1);
    desc_list[1].NEXT_DESC = (unsigned int)&desc_list[2];
    desc_list[1].EOC = 0;

    // -------- Descriptor 2: SDATA segment --------
    desc_list[2].DMASRC = (unsigned int)&__sdata_paddr_start;
    desc_list[2].DMADST = (unsigned int)&__sdata_start;
    desc_list[2].DMALEN = (unsigned int)(&__sdata_end - &__sdata_start + 1);
    desc_list[2].NEXT_DESC = 0x0;  // End of chain
    desc_list[2].EOC = 1;

    // Enable global interrupt
    asm("csrsi mstatus, 0x8"); // MIE of mstatus

    // Enable local interrupt (MEIE)
    asm("li t6, 0x800");
    asm("csrs mie, t6"); // MEIE of mie

    // Set DMA descriptor base
    *dma_desc = (unsigned int)&desc_list[0];

    // Enable DMA controller (start chain)
    *dma_en = 1;

    // Wait for DMA complete interrupt
    asm("wfi");

    // Clean up
    asm("li t6, 0x20");
    asm("csrc mstatus, t6");
    asm("csrwi mip, 0"); // Clear pending interrupt bits
  }
