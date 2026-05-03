
#include <stdio.h>				// needed for printf
#include "DES_M0_SoC.h"			// defines registers in the hardware blocks used
#include "display.h"			// defines registers in the hardware blocks used


void display_accel(int16 y) {
		int pos;
    if (y >  1000) y =  1000;           // clamp
    if (y < -1000) y = -1000;
    pos = (y + 1000) * 15 / 2000;       // map -1000..+1000 → 0..15
    GPIO_LED = (uint16)(1 << pos);      // light one LED at that position
}

void display_mg(int16 val, int is_left_value, int dual_mode) {
		uint8 negative;
		int offset;
    // Set all 8 digits to hex mode, enable only digits 0-3
    DISP_MODE   = 0xFF;                      // hex mode on all digits
		DISP_ENABLE = dual_mode ? 0xFF : 0x0F;   // enable rightmost 8/4 digits led

		if (val >  999) val =  999;  // clamp to 999 to prevent display overflowing
    if (val < -999) val = -999;

    negative = 0;
    if (val < 0) {
      negative = 1;
      val = -val;       // work with positive value
    }

		offset = is_left_value ? 4 : 0; // offset by 4 if writing to left side

    // Write digits right to left (digit 0 = rightmost)
    DISP_DIG(0+offset) = val % 10; val /= 10;
		DISP_DIG(1+offset) = val % 10; val /= 10;
		DISP_DIG(2+offset) = val % 10; val /= 10;

    // digit 3: minus sign if negative, blank otherwise
    DISP_DIG(3+offset) = negative ? 0x11 : 0x1F;    // 0x11 = dash, 0x1F = blank
}
