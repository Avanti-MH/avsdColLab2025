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

// // 這兩個變數是從 data.s 引入的外部符號
extern int array_size;
extern int array_addr[];
extern int _test_start;
int partition(int arr[], int low, int high) {
    int pivot = arr[high];  // Choose the last element as the pivot
    int i = (low - 1);  // Index of smaller element

    for (int j = low; j <= high - 1; j++) {
        if (arr[j] < pivot) {
            i++;  // Increment index of smaller element
            // Swap arr[i] and arr[j]
            int temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }

    // Swap the pivot element with the element at index i + 1
    int temp = arr[i + 1];
    arr[i + 1] = arr[high];
    arr[high] = temp;

    return (i + 1);  // Return the pivot index
}

// Quick Sort function
void quickSort(int arr[], int low, int high) {
    if (low < high) {
        int pi = partition(arr, low, high);  // Find the pivot index

        quickSort(arr, low, pi - 1);  // Recursively sort the left part
        quickSort(arr, pi + 1, high);  // Recursively sort the right part
    }
}

int main() {
    int temp_size = array_size;
    int temp[array_size];
    int low, high;
    // 拆 half-word
    for (int i = 0; i < array_size/2; i++) {
        low = (int16_t)array_addr[i] & 0xFFFF;           // lower half
        high = ((array_addr[i] >> 16) & 0xFFFF); // upper half
        temp[2*i]   = (low & 0x8000) ? (int32_t)(0xFFFF0000 | low) : (int32_t)low;
        temp[2*i+1] = (high & 0x8000) ? (int32_t)(0xFFFF0000 | high) : (int32_t)high;
    }

    // 排序
    quickSort(temp, 0, temp_size - 1);

    // 取樣回寫
    for (int i = 0; i < array_size/2; i++) {
        int lo = (temp[2*i] & 0xFFFF);
        int hi = (temp[2*i+1] << 16);
        *(&_test_start + i) = hi | lo;
        // *(&_test_start + 2*i) = (int16_t)array_addr[i] & 0xFFFF;
        // *(&_test_start + 2*i + 1) = (((int16_t)array_addr[i] >> 16) & 0xFFFF);
    }

    return 0;
}

