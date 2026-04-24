#include <stdio.h>			// needed for printf
#include "DES_M0_SoC.h"		// defines registers in the hardware blocks used
#include "spi.h"			// defines registers in the hardware blocks used
#include "accel.h"			// defines registers in the hardware blocks used

uint8 accel_read_reg(uint8 reg_addr)
{
    /* ------------------------  FROM DATA SHEET pg.19 ------------------------- */
    // The command structure for the read register and write register
    // commands is as follows (see Figure 36 and Figure 37):
    // </CS down> <command byte (0x0A or 0x0B)> <address
    // byte> <data byte> <additional data bytes for multi-byte> …
    // </CS up>
    /* ------------------------------------------------------------------------ */
    SPIselect(0);             // select the accelerometer
    SPIbyte(READ_COMMAND);    // send the read command
    SPIbyte(reg_addr);        // register to read
    uint8 data = SPIbyte(NULL_BYTE);  // send null and recieve data
    SPIselect(1);

    return data;
}

uint8 accel_write_reg(uint8 reg_addr, uint8 value)
{
    /* ------------------------  FROM DATA SHEET pg.19 ------------------------- */
    // The command structure for the read register and write register
    // commands is as follows (see Figure 36 and Figure 37):
    // </CS down> <command byte (0x0A or 0x0B)> <address
    // byte> <data byte> <additional data bytes for multi-byte> …
    // </CS up>
    /* ------------------------------------------------------------------------ */
    SPIselect(0);             // select the accelerometer
    SPIbyte(WRITE_COMMAND);   // send the read command
    SPIbyte(reg_addr);        // register to read
    SPIbyte(value);           // register to write
    SPIselect(1);
}

void accel_setup()
{
    uint8 id = accel_read_reg(DEVID_AD); // Should read 0xAD for analog devices id
    printf("DEVICE ID = 0x%02X\n", id);

    accel_write_reg(FILTER_CTL, 0x13);  // Set to +-2g range, 100 Hz output rate (pg.33 of datasheet)
    accel_write_reg(POWER_CTL, 0x02);  // Set to measurement mode (pg.34 of datasheet)
}

int16 accel_read_y()
{
    SPIselect(0);
    SPIbyte(READ_COMMAND);
    SPIbyte(YDATA_L); // Burst read both high and low fomr one command
    uint8 ylo = SPIbyte(0x00);
    uint8 yhi = SPIbyte(0x00);
    SPIselect(1);

    int16 raw = (int16)((yhi << 8) | ylo);
    return raw >> 4;        // 12-bit signed value (right-justify)
}
