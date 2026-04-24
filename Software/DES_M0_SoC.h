/* DES_M0_SoC.h
	Definitions and structs for System on Chip design assignment.
	This version works without CMSIS.  */


#ifndef DES_M0_HDR_ALREADY_INCLUDED
#define DES_M0_HDR_ALREADY_INCLUDED

// Definitions for the SPI hardware for software to read
#define SPI_BASE   0x52000000
#define SPI_DATA   (*((volatile uint8  *)(SPI_BASE + 0x00)))
#define SPI_CS     (*((volatile uint8  *)(SPI_BASE + 0x04)))
#define SPI_STATUS (*((volatile uint8  *)(SPI_BASE + 0x08)))

#define DISP_BASE  0x53000000
// Each digit is one byte: digit 0 = rightmost, digit 7 = leftmost
#define DISP_DIG(n)  (*((volatile uint8 *)(DISP_BASE + (n))))
#define DISP_MODE    (*((volatile uint8 *)(DISP_BASE + 8)))  // 1=hex mode per digit
#define DISP_ENABLE  (*((volatile uint8 *)(DISP_BASE + 9)))  // 1=on per digit

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
	union  // this union occupies 4 bytes in the address map
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
// bit position defs for the UART status register
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
{					// to make a 16-bit value
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


//=================================================
// Struct for some of the SysTick timer registers - word access only
typedef struct
{
	volatile uint32	CTRL;			// Control and status register
	volatile uint32	LOAD;			// Reload register
	volatile uint32	VAL;			// Current count value
} SysTick_block;

// Simple names for the SysTick registers
#define SysTick_Control (pt2SysTick->CTRL)
#define SysTick_Reload  (pt2SysTick->LOAD)
#define SysTick_Counter (pt2SysTick->VAL)

// Define bit positions for the SysTick control and status register
#define SYSTICK_ENABLE_BIT_POS				0			// 1 enables the SysTick timer
#define SYSTICK_INTERRUPT_BIT_POS			1			// 1 enbales the exception on overflow
#define SYSTICK_CLOCK_SOURCE_BIT_POS	2			// 1 selects the CPU clock
#define SYSTICK_OVERFLOW_BIT_POS			16		// Status - 1 indicates overflow, cleared by read


// =================================================================
// Struct for two of the registers in the NVIC - only word access is allowed here
typedef struct {
	volatile uint32	SETENA;				// Set enable register is at the base address
	volatile uint32	reserved1[0x20-1];  // leave a gap of 0x1F words
	volatile uint32	CLRENA;				// Clear enable register is at base address + 0x20 words
} NVIC_block;

// Simple names for the NVIC registers
#define NVIC_Enable (pt2NVIC->SETENA)
#define NVIC_Disable (pt2NVIC->CLRENA)


#define NVIC_UART_BIT_POS		1      // bit position of UART in ARM's interrupt control register


// =================================================================
// Use the typedefs above to define the memory map
#define pt2NVIC ((NVIC_block *)0xE000E100)
#define pt2SysTick  ((SysTick_block *) 0xE000E010)
#define pt2UART ((UART_block *)0x51000000)
#define pt2GPIO ((GPIO_block *)0x50000000)


#endif
