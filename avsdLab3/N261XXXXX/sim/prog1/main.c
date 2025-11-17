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
// extern int array_size;
// extern int array_addr[];
// extern int _test_start;
// int partition(int arr[], int low, int high) {
//     int pivot = arr[high];  // Choose the last element as the pivot
//     int i = (low - 1);  // Index of smaller element

//     for (int j = low; j <= high - 1; j++) {
//         if (arr[j] < pivot) {
//             i++;  // Increment index of smaller element
//             // Swap arr[i] and arr[j]
//             int temp = arr[i];
//             arr[i] = arr[j];
//             arr[j] = temp;
//         }
//     }

//     // Swap the pivot element with the element at index i + 1
//     int temp = arr[i + 1];
//     arr[i + 1] = arr[high];
//     arr[high] = temp;

//     return (i + 1);  // Return the pivot index
// }

// // Quick Sort function
// void quickSort(int arr[], int low, int high) {
//     if (low < high) {
//         int pi = partition(arr, low, high);  // Find the pivot index

//         quickSort(arr, low, pi - 1);  // Recursively sort the left part
//         quickSort(arr, pi + 1, high);  // Recursively sort the right part
//     }
// }

// void merge(int arr[], int l, int m, int r) {
//     int n1 = m - l + 1;  // Size of left subarray
//     int n2 = r - m;      // Size of right subarray

//     // Create temporary arrays
//     int L[n1], R[n2];

//     // Copy data to temporary arrays L[] and R[]
//     for (int i = 0; i < n1; i++)
//         L[i] = arr[l + i];
//     for (int j = 0; j < n2; j++)
//         R[j] = arr[m + 1 + j];

//     // Merge the temporary arrays back into arr[]
//     int i = 0, j = 0, k = l;
//     while (i < n1 && j < n2) {
//         if (L[i] <= R[j]) {
//             arr[k] = L[i];
//             i++;
//         } else {
//             arr[k] = R[j];
//             j++;
//         }
//         k++;
//     }

//     // Copy the remaining elements of L[], if any
//     while (i < n1) {
//         arr[k] = L[i];
//         i++;
//         k++;
//     }

//     // Copy the remaining elements of R[], if any
//     while (j < n2) {
//         arr[k] = R[j];
//         j++;
//         k++;
//     }
// }

// // Merge Sort function
// void mergeSort(int arr[], int l, int r) {
//     if (l < r) {
//         // Find the middle point
//         int m = l + (r - l) / 2;

//         // Recursively sort the two halves
//         mergeSort(arr, l, m);
//         mergeSort(arr, m + 1, r);

//         // Merge the sorted halves
//         merge(arr, l, m, r);
//     }
// }


// int main() {
//     // 排序
//     int i;
//     for (i = 0; i < array_size; i++) 
//         *(&_test_start + i) = array_addr[i];
//     quickSort(&_test_start, 0, array_size - 1);


//     return 0;
// }

// External symbols from data.s and link.ld
// extern int32_t array_size;
// extern int32_t array_addr[];
// extern volatile int32_t _test_start[];

// #define SIM_END_ADDR 0x0000FFFC
// void main() {
//     int32_t n = array_size;

//     // Copy array from array_addr to _test_start
//     for (int32_t i = 0; i < n; i++) {
//         _test_start[i] = array_addr[i];
//     }

//     // Bubble Sort on _test_start (ascending order, signed)
//     for (int32_t i = 0; i < n; i++) {
//         for (int32_t j = 0; j < n - 1 - i; j++) {
//             if (_test_start[j] > _test_start[j + 1]) {
//                 int32_t temp = _test_start[j];
//                 _test_start[j] = _test_start[j + 1];
//                 _test_start[j + 1] = temp;
//             }
//         }
//     }

//     // Signal simulation end
//     volatile int32_t* sim_end = (volatile int32_t*)SIM_END_ADDR;
//     *sim_end = -1;
// }

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

