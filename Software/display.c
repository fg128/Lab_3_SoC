
#include <stdio.h>					// needed for printf
#include "DES_M0_SoC.h"			// defines registers in the hardware blocks used

void display_accel(int16 y) {
    if (y >  1000) y =  1000;   // clamp
    if (y < -1000) y = -1000;
    int pos = (y + 1000) * 15 / 2000;  // map -1000..+1000 → 0..15
    GPIO_LED = (uint16)(1 << pos);      // light one LED at that position
}
