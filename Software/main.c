/*--------------------------------------------------------------------------------------------------
	Demonstration program for Cortex-M0 SoC design - basic version, no CMSIS

	Enable the interrupt for UART - interrupt when a character is received.
	Repeat:
	  Set the LEDs to match the switches, then flash the 8 rightmost LEDs.
	  Go to sleep mode, waiting for an interrupt
		  On UART interrupt, the ISR sends the received character back to UART and stores it
			  main() also shows the character code on the 8 rightmost LEDs
	  When a whole message has been received, the stored characters are copied to another array
		  with their case inverted, then printed.

	Version 6 - March 2023
  ------------------------------------------------------------------------------------------------*/

#include <stdio.h>				// needed for printf
#include "DES_M0_SoC.h"			// defines registers in the hardware blocks used
#include "accel.h"
#include "display.h"

#define XAXIS_MODE					1 		// Each mode for one hot coded switches
#define YAXIS_MODE					2
#define ZAXIS_MODE					4
#define XYAXIS_MODE					8

#define BUF_SIZE					100				// size of the array to hold received characters
#define ASCII_CR					'\r'			// character to mark the end of input
#define CASE_BIT					('A' ^ 'a')		// bit pattern used to change the case of a letter
#define FLASH_DELAY					1000000			// delay for flashing LEDs, ~220 ms

#define INVERT_LEDS					(GPIO_LED ^= 0xff)		// inverts the 8 rightmost LEDs

#define ARRAY_SIZE(__x__)   (sizeof(__x__)/sizeof(__x__[0]))  // macro to find array size

// Global variables - shared between main and UART_ISR
volatile uint8  RxBuf[BUF_SIZE];	// array to hold received characters
volatile uint8  counter  = 0; 		// current number of characters in RxBuf[]
volatile uint8  BufReady = 0; 		// flag indicates data in RxBuf is ready for processing


//////////////////////////////////////////////////////////////////
// Interrupt service routine, runs when UART interrupt occurs - see cm0dsasm.s
//////////////////////////////////////////////////////////////////
void UART_ISR()
{
	char c;
	c = UART_RXD;	 				// read character from UART (there must be one waiting)
	RxBuf[counter]  = c;  // store in buffer
	counter++;            // increment counter, number of characters in buffer
	UART_TXD = c;  				// write character to UART (assuming transmit queue not full)

	/* Counter is now the position in the buffer that the next character should go into.
		If this is the end of the buffer, i.e. if counter == BUF_SIZE-1, then null terminate
		and indicate that a complete sentence has been received.
		If the character just put in was a carriage return, do the same.  */
	if (counter == BUF_SIZE-1 || c == ASCII_CR)
	{
		counter--;							// decrement counter (CR will be over-written)
		RxBuf[counter] = NULL;  // null terminate to make the array a valid string
		BufReady       = 1;	    // indicate that data is ready for processing
	}
}


//////////////////////////////////////////////////////////////////
// Interrupt service routine for System Tick interrupt
//////////////////////////////////////////////////////////////////
void SysTick_ISR()
{
	// Do nothing - this interrupt is not used here
}


//////////////////////////////////////////////////////////////////
// Software delay function - delay time proportional to argument n
// As a rough guide, delay(1000) takes 160 us to 220 us,
// depending on the compiler optimisation level.
//////////////////////////////////////////////////////////////////
void delay (uint32 n)
{
	volatile uint32 i;
	for(i=0; i<n; i++);		// do nothing n times
}


//////////////////////////////////////////////////////////////////
// Main Function
//////////////////////////////////////////////////////////////////
int main(void)
{
	// uint8 i;		// used in for loop
	int16 left_val, right_val;
	int is_dual;
	uint8 TxBuf[ARRAY_SIZE(RxBuf)];		// serial transmit buffer

// ========================  Initialisation ==========================================

	// Configure the UART - the control register decides which events cause interrupts
	UART_CTL = (1 << UART_RX_FIFO_NOTEMPTY_BIT_POS);	// enable rx data available interrupt only
	// Configure the interrupt system in the processor (NVIC)
	NVIC_Enable = (1 << NVIC_UART_BIT_POS);		// Enable the UART interrupt

	delay(FLASH_DELAY);				// wait a short time
	printf("\n WASUP MY G\n");		// print a welcome message
	accel_setup();					// Setup accelerometer to be used. Prints device ID to test if connected


// ========================  Working Loop ==========================================

	while(1)		// loop forever
	{

		// Do some processing before entering Sleep Mode
		//GPIO_LED	= GPIO_SW; 			// copy 16 switches onto corresponding LEDs
		//delay(FLASH_DELAY);				// short delay
		//INVERT_LEDS;							// invert the 8 rightmost LEDs
		//delay(FLASH_DELAY);				// short delay
		//INVERT_LEDS;							// invert the same LEDs again
		//delay(FLASH_DELAY);				// short delay

		// Ask for user input
		//printf("\nType some characters ");

		//while (BufReady == 0)	// loop until input is ready to process
		//{
		//	__wfi();  // Wait For Interrupt: enter Sleep Mode - wake on character received
		//	// only get to this point if a character has been received
		//	GPIO_LED = RxBuf[counter-1];  // display the code for the character
		//}

		/* Get here when CR is entered or the buffer is full - data is ready for processing.
			Copy the data with UART interrupts disabled, so data does not change.
			The interrupts should only be disabled for a short time, to avoid missing data,
		  so the program only does the minimum necessary in the "critical section". */

		// ---- Start of critical section ----
		NVIC_Disable = (1 << NVIC_UART_BIT_POS);	// disable the UART interrupt

		// Copy the received characters to another array, changing the case of letters
		//for (i=0; i<=counter; i++)		// step through all the bytes received
		//{
		//	if (RxBuf[i] >= 'A') {						// if this character is a letter (roughly)
		//		TxBuf[i] = RxBuf[i] ^ CASE_BIT; // copy to transmit buffer, changing case
		//	}
		//	else {
		//		TxBuf[i] = RxBuf[i];            // not a letter so do not change case
		//	}
		//}

		// Reset the counter and the flag, ready for the next time
		counter  = 0; 		// reset the counter
		BufReady = 0;			// clear the flag

		NVIC_Enable = (1 << NVIC_UART_BIT_POS);		// Enable the UART interrupt
		// ---- End of critical section ----

		// Print the result.  Printing can take a long time, so this is outside the critical section.
		printf("\n:--> |%s| with %d characters\n", TxBuf, counter);  // print the results between bars
		printf("\n switchs: %d\n", GPIO_SW);

		switch(GPIO_SW){
			case XAXIS_MODE:
				// Read x axis data only
				right_val = accel_read(XDATA_L);
				is_dual = 0;
				break;

			case YAXIS_MODE:
				// Read y axis data only
				right_val = accel_read(YDATA_L);
				is_dual = 0;
				break;

			case ZAXIS_MODE:
				// Read z axis data only
				right_val = accel_read(ZDATA_L);
				is_dual = 0;
				break;

			case XYAXIS_MODE:
				// Read x and y axis data
				left_val = accel_read(XDATA_L);
				right_val = accel_read(YDATA_L);
				is_dual = 1; // Dual display shows values on left and right
				break;

			default:
				// Default to read x axis data only
				right_val = accel_read(XDATA_L);
				is_dual = 0;
				break;
		}

		// Print to console measured accelerometer values
		if(is_dual)
		{
			printf("\n x : %d, y : %d,\n", (int)left_val, (int)right_val);
		}
		else
		{
			printf("\n accel value: %d,\n", (int)right_val);
		}

		display_accel(right_val);			// display right value on one LED
		delay(FLASH_DELAY);					// short delay
		display_mg(left_val, 1, is_dual);	// write value to left 4 digits in display
		display_mg(right_val, 0, is_dual);	// write value to right 4 digits in display
	} // end of infinite loop

}  // end of main
