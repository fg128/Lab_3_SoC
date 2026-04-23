/*---------------------------------------------------------------------------------
	Demonstration program for Cortex-M0 SoC design, using CMSIS functions and structs
	Enables two interrupts: UART character received and SysTick timer.
	Uses the Systick timer to measure a time delay.
	Repeat:
		Set the LEDs to match the switches, using 16-bit access to the GPIO registers,
			then flash the 8 leftmost LEDs, using byte access to the GPIO registers.
		Disable SysTick interrupt if button BTND is pressed.
		Print the values of some system registers, as a demonstration.
		Ask for input, then sleep while waiting for an interrupt:
			-	UART ISR puts the received character in a buffer array and sends it back to
				the UART output.  main() displays the character code on the rightmost LEDs
			- SysTick ISR changes the state of the leftmost LED
		When CR character is received, the stored characters are copied to another array
			with their case inverted, then printed. 
	
	Version 6 - March 2023
	-------------------------------------------------------------------------------*/
	
#include <stdio.h>					// for print function
#include "ARMCM0.h"					// includes other files, gives the CMSIS functions and structs
#include "DES_M0_CMSIS.h"		// defines registers in the hardware blocks used

#define BUF_SIZE						100				// size of the array to hold received characters
#define ASCII_CR						'\r'			// character to mark the end of input
#define CASE_BIT						('A' ^ 'a')		// bit pattern used to change the case of a letter
#define FLASH_DELAY					1000000		// delay for flashing LEDs, ~220 ms
#define TEST_DELAY					1000			// delay for testing the delay function

#define INVERT_LEDS_Hi			(GPIO_LED_Hi ^= 0xff)		// invert all bits of the LED_Hi byte
#define MSB8								0x80			// most significant bit of an 8-bit value
#define ST_INT_MASK					0x0002		// SysTick interrupt enable bit mask

#define ARRAY_SIZE(__x__)       (sizeof(__x__)/sizeof(__x__[0]))	// macro to find array size


// Global variables - shared between main and UART_ISR
volatile uint8  RxBuf[BUF_SIZE];	// array to hold received characters
volatile uint8  counter  = 0; 		// current number of characters in RxBuf[]
volatile uint8  BufReady = 0; 		// flag indicates data in RxBuf is ready for processing


//////////////////////////////////////////////////////////////////
// Interrupt service routine, runs when UART has received a character
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
// Interrupt service routine for SysTick interrupt
//////////////////////////////////////////////////////////////////
void SysTick_ISR()	
{
	GPIO_LED_Hi ^= MSB8;		// flip the leftmost LED
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
	uint8 i;		// used in for loop
	uint8 TxBuf[ARRAY_SIZE(RxBuf)];		// serial transmit buffer
	uint32 timeStart, timeEnd;	// variables to hold SysTick values for time measurement

// ========================  Initialisation ==========================================
	
	delay(FLASH_DELAY);										// wait a short time
	
	printf("\n\nWelcome to Cortex-M0 SoC with CMSIS\n");			// print a welcome message
	// Print some values from structs defined in CMSIS - see core_cm0.h
	printf("CPU ID %x SysTick Calibration %x\n", SCB->CPUID, SysTick->CALIB);  

	// Configure the UART to cause an interrupt when data has been received
	UART_CTL = (1 << UART_RX_FIFO_NOTEMPTY_BIT_POS);	// enable rx FIFO not empty interrupt
	
	// Enable the UART interrupt (IRQ1) in the interrupt controller (NVIC), using a function
	// defined in CMSIS (core_cm0.h).  The interrupt number is defined in ARMCM0.h
	NVIC_EnableIRQ(UART_IRQn);		// enable UART interrupt
	
	// Configure SysTick timer for slowest possible overflow rate (~2.98 Hz), using
	// a CMSIS function (core_cm0.h)   This function also enables the interrupt on overflow.
	if ( SysTick_Config(0x1000000) )	// returns 1 on failure, 0 on success
	{
		printf("Failed to configure SysTick timer\n");
	}

	// Measure a time interval using SysTick timer, to calibrate the delay() function
	timeStart = SysTick->VAL;		// capture start time (SysTick struct is in core_cm0.h)
	delay( TEST_DELAY );				// delay a short time
	timeEnd = SysTick->VAL;			// capture end time (lower that start, as counting down)
	printf("delay( %d ) used %d clock cycles\n", TEST_DELAY, 
					(timeStart - timeEnd) & 0x00ffffff);  // mask to 24 bits hides overflow
	
	
// ========================  Working Loop ==========================================
	
	while(1){			// loop forever
			
		// Do some work before entering Sleep Mode
		GPIO_LED	= GPIO_SW; 			// copy 16 switches onto corresponding LEDs
		delay(FLASH_DELAY);				// short delay
		INVERT_LEDS_Hi;						// invert the 8 leftmost LEDs
		delay(FLASH_DELAY);				// short delay
		INVERT_LEDS_Hi;						// invert the 8 leftmost LEDs
		delay(FLASH_DELAY);				// short delay

		/* If BTND is pressed, disable SysTick interrupt for this cycle.
		The NVIC enable register does not control this, but there is a bit in the
		SysTick control register to enable an overflow to cause an interrupt.  */
		if ( GPIO_BUTTON & BTND_MASK ) 		// if button D is pressed at this point
			SysTick->CTRL &= ~ST_INT_MASK;	// disable SysTick interrupt
		else 									// normal situation - button not pressed
			SysTick->CTRL |= ST_INT_MASK;		// enable SysTick interrupt
		
		// Print the values of some system registers for information
		// The structs are defined in CMSIS - see core_cm0.h
		printf("\nSysTick: Control %x Reload %x Current %x\n", 
								SysTick->CTRL, SysTick->LOAD, SysTick->VAL);		// SysTick registers
		printf("\nNVIC: Enable %x Pending %x Priority %x\n", 
								NVIC->ISER[0], NVIC->ISPR[0], NVIC->IP[0]);			// NVIC registers

		// Ask for user input
		printf("\nType some characters: ");
		
		while (BufReady == 0)		// loop until input is ready to process
		{			
			__wfi();  // Wait For Interrupt: enter Sleep Mode until interrupt occurs
			// the interrupt could be due to a received character or SysTick timer overflow
			if ( counter > 0 )	// if at least one character has been received
				GPIO_LED_Lo = RxBuf[counter-1];  // display the code for the last character received
		}

		/* Get here when CR is entered or the buffer is full - data is ready for processing.
			Copy the data with UART interrupts disabled, so data does not change.  
			The interrupts should only be disabled for a short time, to avoid missing data,
		  so the program only does the minimum necessary in the "critical section". */
		
		// ---- Start of critical section ----
		NVIC_DisableIRQ(UART_IRQn);		// disable the UART interrupt
		
		// Copy the received characters to another array, changing the case of letters
		for (i=0; i<=counter; i++)		// step through all the bytes received
		{
			if (RxBuf[i] >= 'A') {						// if this character is a letter (roughly)
				TxBuf[i] = RxBuf[i] ^ CASE_BIT; // copy to transmit buffer, changing case
			}
			else {
				TxBuf[i] = RxBuf[i];            // not a letter so do not change case
			}
		} 
		
		// Reset the counter and the flag, ready for the next time
		counter  = 0; 		// reset the counter	
		BufReady = 0;			// clear the flag
		
		NVIC_EnableIRQ(UART_IRQn);		// enable UART interrupt again
		// ---- End of critical section ----	
		
		// Print the result.  Printing can take a long time, so this is outside the critical section.
		printf("\n:--> |%s|\n", TxBuf);  // print the results between bars
		
	} // end of infinite loop

}  // end of main
