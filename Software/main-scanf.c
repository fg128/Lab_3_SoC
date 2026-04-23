/*--------------------------------------------------------------------------------------------------
	Demonstration program for Cortex-M0 SoC design - basic version, no CMSIS.
	Shows options for user input without interrupts.
	Repeat:
	  Set the LEDs to match the switches, then flash the 8 rightmost LEDs.
		Ask user for text input in various forms and print what is received
		
	Version 3 - March 2023
  ------------------------------------------------------------------------------------------------*/

#include <stdio.h>					// needed for printf
#include "DES_M0_SoC.h"			// defines registers in the hardware blocks used

#define FLASH_DELAY					1000000		// delay for flashing LEDs, ~220 ms
#define INVERT_LEDS					(GPIO_LED ^= 0xff)		// inverts the 8 rightmost LEDs


//////////////////////////////////////////////////////////////////
// Interrupt service routine, runs when UART interrupt occurs - see cm0dsasm.s
//////////////////////////////////////////////////////////////////
void UART_ISR()		
{	
	// this version does nothing - UART interrupts are not used
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
	int number;					// integer variable to hold number input
	char message[30];		// character array to hold text input

	
// ========================  Initialisation ==========================================

	delay(FLASH_DELAY);												// wait a short time
	
	printf("\n\nWelcome to DES SoC (scanf version)\n");			// output welcome message
	

// ========================  Working Loop ==========================================
	
	while(1){			// loop forever
		
		// Flash the LEDs 
		GPIO_LED	= GPIO_SW; 			// copy 16 switches onto corresponding LEDs
		delay(FLASH_DELAY);				// short delay
		INVERT_LEDS;							// invert the 8 rightmost LEDs
		delay(FLASH_DELAY);				// short delay
		INVERT_LEDS;							// invert the same LEDs again
		delay(FLASH_DELAY);				// short delay
		
		// Prompt for user input using scanf() - stops at space, tab or enter
		printf("\nEnter a word (no spaces): ");
		scanf("%28s", message);
		printf("\nYour word was |%s|\n", message);  // print the input between bars

		// Prompt for user input using fgets() - stops at enter, even if nothing else entered
		printf("\nEnter a message (up to 29 characters): ");
		fgets(message, 30, stdin);
		printf("\nYour message was |%s|\n", message);  // print the input between bars

		// Prompt the user to enter a number - stops at anything not part of a number
		printf("\nEnter an integer: ");
		scanf("%d", &number);
		printf("\nYou entered %d\n", number);  // print the input in decimal
			
		} // end of infinite loop

}  // end of main


