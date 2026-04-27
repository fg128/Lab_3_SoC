#ifndef DISPLAY_H
#define DISPLAY_H


#include "DES_M0_SoC.h"			// defines registers in the hardware blocks used


void display_accel(int16 y);
void display_mg(int16 val, int is_left_value, int dual_mode);


#endif

