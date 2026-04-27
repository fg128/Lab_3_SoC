#include <stdio.h>
#include "DES_M0_SoC.h"
#include "spi.h"
#include "accel.h"


uint8 accel_read_reg(uint8 reg_addr)
{
    /* ------------------------  FROM DATA SHEET pg.19 ------------------------- */
    // The command structure for the read register and write register
    // commands is as follows (see Figure 36 and Figure 37):
    // </CS down> <command byte (0x0A or 0x0B)> <address
    // byte> <data byte> <additional data bytes for multi-byte> …
    // </CS up>
    /* ------------------------------------------------------------------------ */
	uint8 data;
    SPIselect(0);                     // select the accelerometer
    SPIbyte(READ_COMMAND);            // send the read command
    SPIbyte(reg_addr);                // register to read
    data = SPIbyte(NULL_BYTE);  	  // send null just to recieve data
    SPIselect(1);

    return data;
}

void accel_write_reg(uint8 reg_addr, uint8 value)
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
    SPIselect(1);             // deselct accelerometer
}

void accel_setup(void)
{
    uint8 id = accel_read_reg(DEVID_AD); // Should read 0xAD for analog devices id
    printf("DEVICE ID = 0x%02X\n", id);

    accel_write_reg(FILTER_CTL, 0x13);   // Set to +-2g range, 100 Hz output rate (pg.33 of datasheet)
    accel_write_reg(POWER_CTL, 0x02);    // Set to measurement mode (pg.34 of datasheet)
}

int16 accel_read(uint8 axis_reg)
{
    /* ------------------------  FROM DATA SHEET pg.19 ------------------------- */
    // The command structure for the read register and write register
    // commands is as follows (see Figure 36 and Figure 37):
    // </CS down> <command byte (0x0A or 0x0B)> <address
    // byte> <data byte> <additional data bytes for multi-byte> …
    // </CS up>
    /* ------------------------------------------------------------------------ */
	int16 raw;
	uint8 ylo, yhi;

    SPIselect(0);
    SPIbyte(READ_COMMAND);
    SPIbyte(axis_reg);          // Burst read both high and low fomr one command
    ylo = SPIbyte(NULL_BYTE);   // send null just to recieve data low byte
    yhi = SPIbyte(NULL_BYTE);   // send null just to recieve data high byte
    SPIselect(1);

    raw = (int16)((yhi << 8) | ylo); // Load raw bytes
    return raw;
}

