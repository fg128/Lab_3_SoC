/*  Low-level stream input-output functions, using UART.
	Based on a template provided by ARM, modified for the SoC Design Assignment.
	Version 3 - March 2022 - includes UART input to support fgetc(), with input 
	characters echoed back to output stream for use with RealTerm or similar. 	*/

#include <stdio.h>
#include "DES_M0_SoC.h"		// defines hardware registers

#define ASCII_CR 13		// carriage return
#define ASCII_LF 10		// line feed

#pragma import(__use_no_semihosting)

struct __FILE { 
	unsigned char * ptr;
	};

FILE __stdout = 	{(unsigned char *)&pt2UART->TxData};
FILE __stdin = 		{(unsigned char *)&pt2UART->RxData};

// Function to output one character through the UART
int uart_out(int ch)
{
	while((pt2UART->Status & (1<<UART_TX_FIFO_FULL_BIT_POS)))	
	{
		// Wait until uart has space in the transmit FIFO
	}
	pt2UART->TxData = (char)ch;
	return(ch);
}

// Function to get one character received through the UART
int uart_in( void )
{
	int ch;
	while(!(pt2UART->Status & (1<<UART_RX_FIFO_NOTEMPTY_BIT_POS)))
	{
		// Wait until there is at least one byte received
	}
	ch = pt2UART->RxData;			// get the received byte
	return(ch);
}

/* Replacement for the standard C function to output a character.
   This version replaces LF with CR LF for correct display on a terminal */
int fputc(int ch, FILE *f)
{
	if (ch == ASCII_LF)		// user is sending \n or line feed
		uart_out(ASCII_CR);	// send \r or carriage return first
	return(uart_out(ch));	// send the character given and return it
}

/* Replacement for the standard C function to input a character.
   This version returns LF when the enter key is pressed, and echoes
   CR LF to the terminal.  It does not implement backspace or delete,
   as they need to be handled at a higher level.  */
int fgetc(FILE *f)
{ 
	int ch = uart_in();		// get a character
	uart_out(ch);			    // echo it back to the terminal
	if (ch == ASCII_CR) 
	{
		uart_out(ASCII_LF);  // if it was return, echo a line feed
		ch = ASCII_LF;			 // and return a line feed
	}
	return ch;
}

/* Replacement file error function, which does nothing.  */
int ferror(FILE *f)
{
  return 0; 
}

/*  Function called when main() exits - usually a return to the 
    operating system.  In a simple embedded system, this should
    never happen, so it is an error.  */
void _sys_exit(void) {
	printf("\nERROR - exit from main()\n");
	while(1); 
}
