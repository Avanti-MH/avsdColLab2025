#include <stdint.h>

// External symbols from data.s and link.ld
extern int32_t array_size;
extern int32_t array_addr[];
extern volatile int32_t _test_start[];

#define SIM_END_ADDR 0x0000FFFC

void main() {
    int32_t n = array_size;

    // Copy array from array_addr to _test_start
    for (int32_t i = 0; i < n; i++) {
        _test_start[i] = array_addr[i];
    }

    // Bubble Sort on _test_start (ascending order, signed)
    for (int32_t i = 0; i < n; i++) {
        for (int32_t j = 0; j < n - 1 - i; j++) {
            if (_test_start[j] > _test_start[j + 1]) {
                int32_t temp = _test_start[j];
                _test_start[j] = _test_start[j + 1];
                _test_start[j + 1] = temp;
            }
        }
    }

    // Signal simulation end
    volatile int32_t* sim_end = (volatile int32_t*)SIM_END_ADDR;
    *sim_end = -1;
}