`timescale 1ns / 1ns
/////////////////////////////////////////////////////////////////
// Module Name: TB_AHBuart - testbench for AHB uart block
/////////////////////////////////////////////////////////////////
module TB_AHBuart(    );

// AHB-Lite Bus Signals
	reg HCLK;					// bus clock
	reg HRESETn;				// bus reset, active low
	reg HSELx = 1'b0;			// selects this slave
	reg [31:0] HADDR = 32'h0;	// address
	reg [1:0] HTRANS = 2'b0;	// transaction type (only two tpyes used)
	reg HWRITE = 1'b0;			// write transaction
	reg [2:0] HSIZE = 3'b0;		// transaction width (max 32-bit supported)
	reg [31:0] HWDATA = 32'h0;	// write data
	wire [31:0] HRDATA;			// read data from slave
    wire HREADY;             	// ready signal - to master and to all slaves
    wire HREADYOUT;             // ready signal output from this slave

// Other signals to connect to the module under test
	wire serialRx, serialTx, uart_IRQ;
	assign serialRx = serialTx;  // loopback connection for testing

// Integer is used in for loops
	integer i = 0;

// Define names for some of the bus signal values and for device register addresses
	localparam [2:0] BYTE = 3'b000, HALF = 3'b001, WORD = 3'b010;	// HSIZE values
	localparam [1:0] IDLE = 2'b00, NONSEQ = 2'b10;					// HTRANS values
	localparam [31:0] RXDATA = 32'h5100_0000, TXDATA = 32'h5100_0004, 
	                   STATUS = 32'h5100_0008, CONTRL = 32'h5100_000c;	// registers

// Instantiate the design under test and connect it to the testbench signals
// Some bus signals are not used - this design ignores HSIZE, for example
	AHBuart dut(
		.HCLK(HCLK),
		.HRESETn(HRESETn),
		.HSEL(HSELx),
		.HREADY(HREADY),
		.HADDR(HADDR),
		.HTRANS(HTRANS),
		.HWRITE(HWRITE),  
		.HWDATA(HWDATA),  
		.HRDATA(HRDATA),  
		.HREADYOUT(HREADYOUT),
		.HRESP(HRESP),
		.serialRx(serialRx),
		.serialTx(serialTx),
		.uart_IRQ(uart_IRQ)
		);

// Generate the clock signal at 50 MHz - period 20 ns
	initial
		begin
			HCLK = 1'b0;
			forever
				#10 HCLK = ~HCLK;  // invert clock every 10 ns
		end

// Generate reset pulse and simulate some bus transactions.  The AHBuart block has
// four 8-bit registers, at word addresses.  It ignores the HSIZE signal, so the registers
// can be accessed using word, half-word or byte transactions.
	initial
		begin
			HRESETn = 1'b1;			// reset inactive at start
			#20 HRESETn = 1'b0;		// reset active on falling edge of clock
			#20 HRESETn = 1'b1;		// inactive after one clock cycle
			#50;					// delay to see what happens
			AHBwrite(BYTE, CONTRL, 8'hc);	// enable rx interrupts
			AHBwrite(WORD, TXDATA, 32'h12348765);	// transmit data - only 8 bits are used
            AHBread (WORD, TXDATA, 32'h65);            // read back data
			AHBidle;	// need to put bus in idle state unless another transaction follows immediately
			#20;		// leave a short gap - transmission is still in progress
			AHBread (BYTE, STATUS, 8'h2);	// read status: expect tx FIFO empty, rx FIFO empty
			AHBidle;	// need to put bus in idle state unless another transaction follows immediately
			wait (uart_IRQ == 1'b1);		// wait for interrupt when first byte has been received
			AHBread (BYTE, STATUS, 8'ha);	// read status: expect rx buffer not empty, tx empty
            AHBread (BYTE, RXDATA, 8'h65);  // read received data - should be the byte just sent
			AHBidle;	// need to put bus in idle state unless another transaction follows immediately
            #40;        // leave a short gap
			AHBwrite(BYTE, TXDATA, 8'ha7);	// send more data - 2 bytes this time
			AHBwrite(BYTE, TXDATA, 8'h34);  // second byte should remain in FIFO while first byte is sent
			AHBread (BYTE, STATUS, 8'h0);	// read status: expect tx FIFO not empty, rx still empty
			AHBread (WORD, CONTRL, 32'hc);	// readback of control register - should not have changed
			for (i=0; i<20; i=i+1)
				AHBwrite(WORD, TXDATA, i+20);	// transmit data to fill the transmit FIFO
			AHBread (BYTE, STATUS, 8'h1);	// read status: expect tx full, rx still empty
			AHBidle;
			wait (uart_IRQ == 1'b1);		// wait for interrupt when a byte has been received
			AHBread (BYTE, STATUS, 8'h8);	// read status: expect rx FIFO not empty, tx no longer full
			AHBread (BYTE, RXDATA, 8'ha7);	// read received data - should be the first byte sent
			AHBidle;
			@ (posedge uart_IRQ );			// another way to wait for interrupt
			AHBread (BYTE, STATUS, 8'h8);	// read status: expect rx FIFO not empty, tx not full
			AHBread (BYTE, RXDATA, 8'h34);	// read received data, expect to read the second byte sent
			AHBidle;
			@ (posedge uart_IRQ );			// wait for interrupt
			AHBread (BYTE, STATUS, 8'h8);	// read status: expect both FIFOs have some data
			AHBread (BYTE, RXDATA, 8'd20);	// read received data - expect to read the third byte sent
			AHBread (BYTE, STATUS, 8'h0);	// read status: expect tx FIFO has data, rx empty
			AHBwrite(BYTE, CONTRL, 8'h2);	// enable tx buffer empty interrupt only
			AHBidle;
			@ (posedge uart_IRQ );			// wait for interrupt - tx buffer is now empty
			AHBread (BYTE, STATUS, 8'ha);	// read status: tx buffer empty, rx buffer has data
			AHBread (BYTE, RXDATA, 8'd21);	// read received data - expect fourth byte
			AHBread (BYTE, RXDATA, 8'd22);	// read received data - expect fifth byte			
			AHBread (BYTE, RXDATA, 8'd23);	// read received data - expect sixth byte
			AHBidle;	
			#5000;							// delay to allow actions to complete
			$stop;							// stop the simulation
		end


// =========== AHB bus tasks - crude models of bus activity =========================
// To use these tasks, include everything below this line, until the next ===== line
// Read and Write tasks do not restore the bus to idle, as another transaction might follow.
// Use AHBidle task immediately after read or write if no transaction follows immediately.

	reg [31:0] nextWdata = 32'h0;		// delayed data for write transactions
	reg [31:0] expectRdata = 32'h0;		// expected read data for read transactions
	reg [31:0] rExpectRead;				// store expected read data
	reg [4:0]  rReadType;               // store size and position of read data 
	reg checkRead;						// remember that read is in progress
	reg [31:0] readCapture = 32'h0;     // to capture read data on clock edge
	reg transState;						// state of our transaction - 1 if in data phase
	reg error = 1'b0;  // read error signal - asserted for one cycle AFTER read completes
	integer errCount = 0;				// error counter
    
// Task to simulate a write transaction on AHB Lite
	task AHBwrite ( 
			input [2:0] size,	// transaction width - BYTE, HALF or WORD
			input [31:0] addr,	// address
			input [31:0] data );	// data to be written, right-justified
		begin
			wait (HREADY == 1'b1);	// wait for ready signal - previous transaction completing
			@ (posedge HCLK);	// align with clock
			#1 HSIZE = size;	// set up signals for address phase, just after clock edge
			HTRANS = NONSEQ;	// transaction type non-sequential
			HWRITE = 1'b1;		// write transaction
			HADDR = addr;		// put address on bus
			HSELx = 1'b1;		// select this slave
			#1;	// a little later, store data for use in the data phase
			// write data must be aligned according to size and LSBs of address
			case ({size, addr[1:0]})
			  5'b000_00: 	nextWdata = data & 8'hff;  // byte write LSB
			  5'b000_01: 	nextWdata = (data & 8'hff) << 8;  // byte write next byte
			  5'b000_10: 	nextWdata = (data & 8'hff) << 16;  // byte write next byte
			  5'b000_11: 	nextWdata = (data & 8'hff) << 24;  // byte write MSB
			  5'b001_00: 	nextWdata = data & 16'hffff;  // half word write LSH
			  5'b001_10: 	nextWdata = (data & 16'hffff) << 16;  // half word write MSH
			  5'b010_00: 	nextWdata = data;  // word write
			  default:      nextWdata = 32'hdeadbeef;    // anything else is invalid
			endcase
		end
	endtask

// Task to simulate a read transaction on AHB Lite
	task AHBread (
			input [2:0] size,	// transaction width - BYTE, HALF or WORD
			input [31:0] addr,	// address
			input [31:0] data );	// expected data from slave
		begin  
			wait (HREADY == 1'b1);	// wait for ready signal - previous transaction completing
			@ (posedge HCLK);	// align with clock
			#1 HSIZE = size;	// set up signals for address phase, just after clock edge
			HTRANS = NONSEQ;	// transaction type non-sequential
			HWRITE = 1'b0;		// read transaction
			HADDR = addr;		// put address on bus
			HSELx = 1'b1;		// select this slave
			#1 expectRdata = data;	// a little later, store expected data for checking in the data phase
		end
	endtask

// Task to put bus in idle state after read or write transaction
	task AHBidle;
		begin  
			wait (HREADY == 1'b1); // wait for ready signal - previous transaction completing
			@ (posedge HCLK);	// then wait for clock edge
			#1 HTRANS = IDLE;	// set transaction type to idle
			HSELx = 1'b0;		// deselect the slave
		end
	endtask

// Control the HWDATA signal during the data phase
	always @ (posedge HCLK)
		if (~HRESETn) HWDATA <= 32'b0;
		else if (HSELx && HWRITE && HTRANS && HREADY) // our write transaction is moving to data phase
			#1 HWDATA <= nextWdata;	// change HWDATA shortly after the clock edge
		else if (HREADY)	// some other transaction in progress
			#1 HWDATA <= {HADDR[31:24], HADDR[11:0], 12'hbad}; // put rubbish on HWDATA

// Registers to hold expected read data during data phase, data size and position
// and a flag to indicate that read is in progress
	always @ (posedge HCLK)
		if (~HRESETn)
			begin
				rExpectRead <= 32'b0;
				rReadType <= 5'b0;
				checkRead <= 1'b0;
			end
		else if (HSELx && ~HWRITE && HTRANS && HREADY)  // our read transaction moving to data phase
			begin
			    // first update expected read register with expected data
				if (HSIZE == 3'b0) rExpectRead <= expectRdata & 8'hff;  // byte read
				else if (HSIZE == 3'b1) rExpectRead <= expectRdata & 16'hffff;  // half word read
				else rExpectRead <= expectRdata;	// word read (or larger, not supported)
				
				rReadType <= {HSIZE, HADDR[1:0]};  // also store size and address bits
				checkRead <= 1'b1;	// and set flag to get read data checked on next clock edge
			end
		else if (HREADY)	// some other transaction moving to data phase
				checkRead <= 1'b0;			// clear flag - no check needed

// Check the read data as the read transaction completes
// Error signal will be asserted for one cycle AFTER problem detected
	always @ (posedge HCLK)
		if (~HRESETn) error <= 1'b0;
		else if (checkRead & HREADY)	// our read transaction is completing on this clock edge
		  begin
		    case (rReadType)  // capture the appropriate data from the bus
			  5'b000_00: 	 readCapture = HRDATA & 8'hff;  // byte read LSB
              5'b000_01:     readCapture = (HRDATA >> 8) & 8'hff;  // byte read next byte
              5'b000_10:     readCapture = (HRDATA >> 16) & 8'hff;  // byte read next byte
              5'b000_11:     readCapture = (HRDATA >> 24) & 8'hff;  // byte read MSB
              5'b001_00:     readCapture = HRDATA & 16'hffff;       // half word read LSH
              5'b001_10:     readCapture = (HRDATA >> 16) & 16'hffff; // half word read MSH
              default:       readCapture = HRDATA;  // word read (anything else is invalid)
            endcase
            
            // compare captured data with expected read data
			if (readCapture != rExpectRead)	// the captured data is not as expected
				begin
					error <= 1'b1;		// so flag this as an error
					errCount = errCount + 1;	// and increment the error counter
				end
			else error <= 1'b0;			// otherwise our read transaction is OK
		  end  // end checking our read transaction
		  
		else		// this is some other transaction 
			error <= 1'b0;	// so no error
			
// Control the HREADY signal during the data phase
	always @ (posedge HCLK)
		if (~HRESETn) transState <= 1'b0;	// after reset, this is not the data phase of our transaction
		else if (HSELx && HTRANS && HREADY) // transaction with this slave is moving to data phase
			#1 transState <= 1'b1;			// so this slave controls HREADY
		else if (HREADY)					// idle, or some other transaction is moving to data phase
			#1 transState <= 1'b0;			// some other slave controls HREADY
			
	assign HREADY = transState ? HREADYOUT : 1'b1;     // other slave is always ready

//============================= END of AHB bus tasks =========================================



endmodule
