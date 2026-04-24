#include "DES_M0_SoC.h"			// defines registers in the hardware blocks used

/* ------------------------- ACCELEROMETER COMMANDS ------------------------- */
#define WRITE_COMMAND 0x0A
#define READ_COMMAND 0x0B
#define READ_FIFO_COMMAND 0x0D
#define NULL_BYTE 0x00

/* ----------- TABLE 11 REGISTER MAP FROM ACCELEROMETER DATASHEET ----------- */
/* Device Identification */
#define DEVID_AD          0x00
#define DEVID_MST         0x01
#define PARTID            0x02
#define REVID             0x03

/* Data Registers (8-bit) */
#define XDATA             0x08
#define YDATA             0x09
#define ZDATA             0x0A
#define STATUS            0x0B

/* FIFO Entry Count */
#define FIFO_ENTRIES_L    0x0C
#define FIFO_ENTRIES_H    0x0D

/* Data Registers (16-bit, low/high) */
#define XDATA_L           0x0E
#define XDATA_H           0x0F
#define YDATA_L           0x10
#define YDATA_H           0x11
#define ZDATA_L           0x12
#define ZDATA_H           0x13

/* Temperature */
#define TEMP_L            0x14
#define TEMP_H            0x15

/* Reserved: 0x16, 0x17 */

/* Soft Reset */
#define SOFT_RESET        0x1F

/* Activity Detection */
#define THRESH_ACT_L      0x20
#define THRESH_ACT_H      0x21
#define TIME_ACT          0x22

/* Inactivity Detection */
#define THRESH_INACT_L    0x23
#define THRESH_INACT_H    0x24
#define TIME_INACT_L      0x25
#define TIME_INACT_H      0x26
#define ACT_INACT_CTL     0x27

/* FIFO Control */
#define FIFO_CONTROL      0x28
#define FIFO_SAMPLES      0x29

/* Interrupt Mapping */
#define INTMAP1           0x2A
#define INTMAP2           0x2B

/* Configuration */
#define FILTER_CTL        0x2C
#define POWER_CTL         0x2D
#define SELF_TEST         0x2E


/* --------------------------- FUNCTION PROTOTYPES -------------------------- */
uint8 accel_read_reg(uint8 reg_addr);
uint8 accel_write_reg(uint8 reg_addr, uint8 value);
void accel_setup();
int16 accel_read_y();


