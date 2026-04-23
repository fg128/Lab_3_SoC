/* DES_M0_CMSIS.h
	Definitions and structs for System on Chip design assignment.
	This version assumes CMSIS is being used, so no need to 
	provide support for NVIC or SysTick timer.  */
	
#ifndef DES_M0_HDR_ALREADY_INCLUDED
#define DES_M0_HDR_ALREADY_INCLUDED

//  Type definitions for integers
typedef unsigned       char uint8;
typedef   signed       char  int8;
typedef unsigned short int  uint16;
typedef   signed short int   int16;
typedef unsigned       int  uint32;
typedef   signed       int   int32;

#pragma anon_unions


// =================================================================
// Struct for registers in UART hardware
typedef struct 
{
	union // this union occupies 4 bytes in the address map
	{
		volatile uint8   RxData;		// 1-byte register, LSB 
		volatile uint32  reserved0; // overlapping with 4 byte value
	};
	union  // this union occupies the next 4 bytes
	{
		volatile uint8   TxData;
		volatile uint32  reserved1;
	};
	union 
	{
		volatile uint8   Status;
		volatile uint32  reserved2;
	};
	union 
	{
		volatile uint8   Control;
		volatile uint32  reserved3;
	};
} UART_block;

// Define bit positions for the UART control and status registers
#define UART_TX_FIFO_FULL_BIT_POS		0			// Tx FIFO full
#define UART_TX_FIFO_EMPTY_BIT_POS	1			// Rx FIFO empty
#define UART_RX_FIFO_FULL_BIT_POS		2			// Rx FIFO full
#define UART_RX_FIFO_NOTEMPTY_BIT_POS	3		// Rx FIFO not empty (data available)

// Simple names for the UART registers
#define UART_RXD (pt2UART->RxData)
#define UART_TXD (pt2UART->TxData)
#define UART_STS (pt2UART->Status)
#define UART_CTL (pt2UART->Control)


// =================================================================
// Structs for registers in the GPIO hardware
struct TwoByte		// this combines two 8-bit values
{									// to make a 16-bit value
	volatile uint8 Lo;
	volatile uint8 Hi;
};

typedef struct 		// matches the registers in GPIO hardware
{
	union 					// union occupies 4 bytes in the address map
	{
		volatile uint16  Out0;		// 16-bit hardware register
		struct TwoByte OUT0;			// can also access as two 8-bit registers
		volatile uint32  reserved0;		// overlapping 4-byte value
	};
	union 
	{
		volatile uint16  Out1;
		struct TwoByte OUT1;
		volatile uint32  reserved1;
	};
	union 
	{
		volatile uint16  In0;
		struct TwoByte IN0;
		volatile uint32  reserved2;
	};
	union 
	{
		volatile uint16  In1;
		struct TwoByte IN1;
		volatile uint32  reserved3;
	};
} GPIO_block;

// Simple names for the GPIO registers, as used in the SoC assignment
#define GPIO_LED  	(pt2GPIO->Out0)				// output port 0 is connected to 16 LEDs
#define GPIO_LED_Lo (pt2GPIO->OUT0.Lo)		// allow access to the 8 rightmost LEDs
#define GPIO_LED_Hi (pt2GPIO->OUT0.Hi)		// allow access to the 8 leftmost LEDs
#define GPIO_SW			(pt2GPIO->In0)				// input port 0 is connected to 16 switches
#define GPIO_SW_Lo	(pt2GPIO->IN0.Lo)			// allow access to the 8 rightmost switches
#define GPIO_SW_Hi	(pt2GPIO->IN0.Hi)			// allow access to the 8 leftmost switches
#define GPIO_BUTTON	(pt2GPIO->In1)				// input port 1 is connected to 5 buttons

// Button masks - as in the example hardware in the SoC assignment
#define BTNU_MASK		(0x10)		// use to select the input from BTNU only
#define BTND_MASK		(0x08)
#define BTNL_MASK		(0x04)
#define BTNC_MASK		(0x02)
#define BTNR_MASK		(0x01)


// =================================================================
// Struct for an array of registers for the display hardware
typedef struct 
{
		volatile uint8 digit[8];  // set of 8 digit registers
		volatile uint8 mode;			// mode register
		volatile uint8 enable;		// enable register
} DISP_block;


// =================================================================
// Pointers to the structs above, to define the memory map
#define pt2GPIO ((GPIO_block *)0x50000000)
#define pt2UART ((UART_block *)0x51000000)
#define pt2Disp ((DISP_block *)0x53000000)

#endif
