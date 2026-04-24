`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: UCD School of Electrical and Electronic Engineering
// Engineer: Brian Mulkeen, with fifo blocks from ARM
//
// Create Date:   20 October 2014
// Design Name: 	Cortex-M0 DesignStart system
// Module Name:   AHBuart
// Description: 	Provides asynchronous serial transmitter and receiver on AHB.
//					Transmit and receive paths have 16-byte FIFO buffers.
//		Address 0 - receive data, 8 bits, from FIFO, read only
//		Address 4 - transmit data, 8-bits, to FIFO (read gives FIFO output)
//		Address 8 - status, read only: 	bit 0 = tx FIFO full
//										bit 1 = tx FIFO empty
//										bit 2 = rx FIFO full
//										bit 3 = rx FIFO not empty - data available
//		Address C - control - four interrupt enable bits, 1 enables corresponding status
//					bit to cause interrupt, 0 blocks the interrupt (default).
//		This version provides simple level-based interrupt signal from the status bits.
//		The only way to clear an interrupt request is to remove the problem or clear the enable bit.
//		All transfers 32 bits, with data bits right-justified, filled with 0 on left on read.
// Revision:
// Revision 0.01 - File Created
// Revision 1 - modified for synchronous reset, October 2015
// Revision 2 - added HRESP output, March 2024
//
//////////////////////////////////////////////////////////////////////////////////
module AHBspi(
			// Bus signals
			input  HCLK,			// bus clock
			input  HRESETn,			// bus reset, active low
			input  HSEL,			// selects this slave
			input  HREADY,			// indicates previous transaction completing
			input  [31:0] HADDR,	// address
			input  [1:0] HTRANS,	// transaction type (only bit 1 used)
			input  HWRITE,			// write transaction
			input  [2:0] HSIZE,		// transaction width ignored
			input  [31:0] HWDATA,	// write data
			output [31:0] HRDATA,	// read data from slave
			output HREADYOUT,		// ready output from slave
			output HRESP,			// response output from slave

			// SPI signals
			input  aclMISO,			// accelerometer SPI MISO signal
			output aclMOSI,         // accelerometer SPI MOSI signal
            output aclSCK,          // accelerometer SPI clock signal
            output aclSSn           // accelerometer slave select signal, active low
    );
	/* ------------------ Capture bus signals in address phase ------------------ */
    // Registers to hold signals from address phase
	reg [1:0] rHADDR;			// only need two bits of address
	reg rWrite, rRead;	// write enable signals
	always @(posedge HCLK)
		if(!HRESETn)
			begin
				rHADDR <= 2'b0;
				rWrite <= 1'b0;
				rRead  <= 1'b0;
			end
		else if(HREADY)
            begin
                rHADDR <= HADDR[3:2];         // capture address bits for for use in data phase
                rWrite <= HSEL &  HWRITE & HTRANS[1];	// slave selected for write transfer
                rRead  <= HSEL & ~HWRITE & HTRANS[1];	// slave selected for read transfer
            end

    /* -------------------------- Chip select register -------------------------- */
	reg CS;	// Stores software chip select in address 4
	always @(posedge HCLK)
		if (!HRESETn) CS <= 1'b1;
		else if (rWrite && (rHADDR == 2'h1)) CS <= HWDATA[0]; // Write software to chip select
    assign aclSSn = CS;

    /* ------------------------- State machine operation ------------------------ */
    localparam CLK_DIV      = 4'd8;
    localparam MAX_SHIFTS   = 4'd15;
    localparam IDLE         = 2'd0;
    localparam SHIFT        = 2'd1;
    localparam DONE         = 2'd2;

    reg busy;                   // Register to trakc if currently busy
    reg sck_reg;                // Register to trakc sck
    reg[1:0] state;             // Register to track state
    reg[3:0] clk_counter;       // Register to count clock to 8
    reg[3:0] shift_counter;     // Register to count clock to 8
    reg[7:0] shift_tx;          // register to transfer shift
    reg[7:0] shift_rx;          // register to recive shift

    // Stores start data in address 0
    wire DATA = rWrite & (rHADDR == 2'h0); // Write software to start
    wire start = DATA;          // write to DATA addr triggers transfer

    always @(posedge HCLK) begin
        if (!HRESETn) begin
            // Reset all values to know shit
            state         <= IDLE;
            clk_counter   <= 4'd0;
            shift_counter <= 4'd0;
            sck_reg       <= 1'b0;
            busy          <= 1'b0;
            shift_tx      <= 8'd0;
            shift_rx      <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    sck_reg <= 0;
                    if (start) begin
                        busy          <= 1'b1;        // Raise busy flag
                        clk_counter   <= 4'd0;
                        shift_counter <= 4'd0;
                        shift_tx      <= HWDATA[7:0]; // Shift data into tx
                        state         <= SHIFT;       // Change state to shifting
                    end
                end

                SHIFT: begin
                    clk_counter <= clk_counter + 1;
                    if (clk_counter == CLK_DIV - 1) begin
                        clk_counter   <= 0;
                        sck_reg       <= ~sck_reg;
                        shift_counter <= shift_counter + 1;

                        // SPI mode 0 logic
                        if (!sck_reg) begin
                            // Rising SCLK so shift in data left
                            shift_rx <= {shift_rx[6:0], aclMISO};
                        end else begin
                            // Falling SCLK so shift out data left
                            shift_tx <= {shift_tx[6:0], 1'b0};
                        end

                        if (shift_counter == MAX_SHIFTS) begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    busy    <= 1'b0;
                    sck_reg <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE
            endcase
        end
    end

    assign aclMOSI = shift_tx[7];
    assign aclSCK  = sck_reg;

    /* ----------------------- Read Software Multiplexing ----------------------- */
    reg[7:0] readData;
    always @(*) begin
        case (rHADDR)
            2'h0: readData <= shift_rx;     // Received byte
            2'h1: readData <= {7'b0, CS};   // Chip select
            2'h2: readData <= {7'b0, busy}; // Status
            default: readData <= 8'h00;
        endcase
    end

    assign HRDATA    = {24'b0, readData};
    assign HREADYOUT = 1'b1;   // software polls busy bit, no wait states needed
    assign HRESP     = 1'b0;   // always OKAY
endmodule
