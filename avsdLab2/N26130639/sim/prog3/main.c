#include <stdint.h>

// External symbols from data.s and link.ld
extern int32_t div1;             // First number (0x07622814)
extern int32_t div2;             // Second number (0x00421923)
extern volatile int32_t _test_start[]; // Result storage (in _test, dmem, writable)

#define SIM_END_ADDR 0x0000FFFC

// GCD function using Euclidean algorithm
int32_t gcd(int32_t a, int32_t b) {
    // Take absolute values to ensure positive GCD
    if (a < 0) a = -a;
    if (b < 0) b = -b;

    while (b != 0) {
        int32_t temp = b;
        b = a % b;
        a = temp;
    }
    return a;
}

void main() {
    // Load div1 and div2
    int32_t a = div1; // 123346452
    int32_t b = div2; // 4331747

    // Calculate GCD and store in _test_start[0]
    _test_start[0] = gcd(a, b);

    // Signal simulation end
    volatile int32_t* sim_end = (volatile int32_t*)SIM_END_ADDR;
    *sim_end = -1;
}