`timescale 1ns / 1ns
/////////////////////////////////////////////////////////////////
// Module Name: TB_AHBgpio - testbench for AHBgpio block
/////////////////////////////////////////////////////////////////
module TB_AHBgpio(    );

// AHB-Lite Bus Signals
	reg HCLK;					// bus clock
	reg HRESETn;				// bus reset, active low
	reg HSELx = 1'b0;			// selects this slave
	reg [31:0] HADDR = 32'h0;	// address
	reg [1:0] HTRANS = 2'b0;	// transaction type (only two types used)
	reg HWRITE = 1'b0;			// write transaction
	reg [2:0] HSIZE = 3'b0;		// transaction width (max 32-bit supported)
	reg [31:0] HWDATA = 32'h0;	// write data
	wire [31:0] HRDATA;			// read data from slave
    wire HREADY;             	// ready signal - to master and to all slaves
    wire HREADYOUT;         	// ready signal output from this slave

// GPIO input and output signals
	reg [15:0] gpio_in0 = 16'h2345, gpio_in1 = 16'habcd;	// input ports with initial values
	wire [15:0] gpio_out0, gpio_out1;	// output ports

   
// Define names for some of the bus signal values
	localparam [2:0] BYTE = 3'b000, HALF = 3'b001, WORD = 3'b010;			// HSIZE values
	localparam [1:0] IDLE = 2'b00, NONSEQ = 2'b10;							// HTRANS values
// Define names for the register addresses - first the word addresses, assuming base address 0x50000000
	localparam [31:0] OUT0 = 32'h5000_0000, OUT1 = 32'h5000_0004, IN0 = 32'h5000_0008, IN1 = 32'h5000_000c;
// Then the byte addresses - only two bytes exist in each register
	localparam [31:0] OUT0L = 32'h5000_0000, OUT0H = 32'h5000_0001, OUT1L = 32'h5000_0004, OUT1H = 32'h5000_0005;
	localparam [31:0] IN0L = 32'h5000_0008,  IN0H = 32'h5000_0009,  IN1L = 32'h5000_000c,  IN1H = 32'h5000_000d;

// Instantiate the design under test and connect it to the testbench signals
	AHBgpio dut(
		.HCLK         (HCLK),
		.HRESETn      (HRESETn),
		.HSEL         (HSELx),
		.HREADY       (HREADY),
		.HADDR        (HADDR),
		.HTRANS       (HTRANS),
		.HWRITE       (HWRITE),  
		.HSIZE        (HSIZE), 
		.HWDATA       (HWDATA),  
		.HRDATA       (HRDATA),  
		.HREADYOUT    (HREADYOUT),
		.gpio_out0    (gpio_out0),
		.gpio_out1    (gpio_out1),
		.gpio_in0     (gpio_in0),
		.gpio_in1     (gpio_in1)
		);

// Generate the clock signal at 50 MHz - period 20 ns
	initial
		begin
			HCLK = 1'b0;
			forever
				#10 HCLK = ~HCLK;  // invert clock every 10 ns
		end

// Generate reset pulse and simulate some bus transactions to implement the verification plan
	initial
		begin
			HRESETn = 1'b1;			// reset inactive at start
			#20 HRESETn = 1'b0;		// reset active on falling edge of clock
			#20 HRESETn = 1'b1;		// inactive after one clock cycle
			#50;					// delay to see what happens
			AHBwrite(WORD, OUT0, 32'h1a2b3c4d);	// write word to address for output 0 register
			AHBwrite(WORD, OUT1, 32'h12345678); // write word to output 1 register
			AHBread (WORD, OUT1, 32'h00005678);	// read output 1 register, expect 16 bits of value written
			AHBwrite(WORD, IN0,  32'hf0f0f1d8);	// read-only register, write should have no effect
			AHBread (WORD, IN0,  32'h00002345);	// read in0 port, should still be 2345
			AHBread (HALF, IN1,  16'habcd);	    // half-word read in1 port, should be abcd
			AHBidle;	// must put bus into idle state unless another transaction follows immediately
			repeat(5)
				@ (posedge HCLK);		// wait 5 clock cycles
			gpio_in0 = 16'h4321;		// change GPIO input values
			gpio_in1 = 16'hdcba;
			AHBread (WORD, OUT0, 32'h00003c4d);	 // read all registers as 32-bit words
			AHBread (WORD, IN0,  32'h00002345);	 // wrong expected data to show error counting
			AHBread (WORD, IN1,  32'h0000dcba);
			AHBread (WORD, OUT1, 32'h00005678);
			AHBidle;
			repeat(5)
				@ (posedge HCLK);		// wait 5 clock cycles
			AHBwrite(BYTE, OUT0H, 8'h90);	     // test the byte write facility
			AHBwrite(BYTE, OUT1L, 8'hee);	     // only half of each register should change
			AHBread (BYTE, OUT1L, 8'hee);	     // byte read to check the result
			AHBread (BYTE, OUT1H, 8'h56);        // byte read to check the other half
			AHBread (HALF, OUT1, 16'h56ee);      // half word read to check all
			AHBread (WORD, OUT0, 32'h0000904d);  // check out0 - full word
			AHBread (HALF, OUT0, 16'h904d);      // check out0 - half word
			AHBread (HALF, IN1,  16'hdcba);      // check in1 - half word
			AHBread (BYTE, IN1H,  8'hdc);        // check in1 - byte
			AHBidle;
			#50;			// wait a while to allow the last transaction to complete
			$stop;			// stop the simulation
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
