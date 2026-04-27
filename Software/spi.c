#include <stdio.h>
#include "DES_M0_SoC.h"
#include "spi.h"


void SPIselect(int select)
{
    SPI_CS = select;                // select the SPI device
}

uint8 SPIbyte(uint8 send) {
    SPI_DATA = send;                // writing triggers the transfer
    while (SPI_STATUS & 1);         // wait until busy bit clears
    return SPI_DATA;                // return received byte
}


