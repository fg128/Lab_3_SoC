
#include <stdio.h>					// needed for printf
#include "DES_M0_SoC.h"			// defines registers in the hardware blocks used

void display_accel(int16 y) {
    if (y >  1000) y =  1000;   // clamp
    if (y < -1000) y = -1000;
    int pos = (y + 1000) * 15 / 2000;  // map -1000..+1000 → 0..15
    GPIO_LED = (uint16)(1 << pos);      // light one LED at that position
}

// Displays a signed number in mg on the 7-segment display
// e.g. -512 shows as "- 5 1 2" on rightmost 4 digits
void display_mg(int16 val) {
    // Set all 8 digits to hex mode, enable only digits 0-3
    DISP_MODE   = 0xFF;   // hex mode on all digits
    DISP_ENABLE = 0x0F;   // enable rightmost 4 digits only

    uint8 negative = 0;
    if (val < 0) {
        negative = 1;
        val = -val;       // work with positive value
    }

    // Write digits right to left (digit 0 = rightmost)
    DISP_DIG(0) = val % 10;
	val /= 10;
    DISP_DIG(1) = val % 10;
	val /= 10;
    DISP_DIG(2) = val % 10;
	val /= 10;
    // digit 3: minus sign if negative, blank otherwise
    DISP_DIG(3) = negative ? 0x11 : 0x1F;    // 0x11 = dash, 0x1F = blank
}
