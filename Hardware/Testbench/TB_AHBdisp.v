`timescale 1ns / 1ns
/////////////////////////////////////////////////////////////////
// Module Name: TB_AHBdisp - testbench for AHB display block
/////////////////////////////////////////////////////////////////
module TB_AHBdisp (    );

// Create AHB-Lite bus signals
	reg HCLK;				      // bus clock
    reg HRESETn;                  // bus reset, active low
    reg HSELx = 1'b1;             // selects this slave
    reg [31:0] HADDR = 32'h0;     // address
    reg [1:0] HTRANS = 2'b0;      // transaction type (only bit 1 used)
    reg [2:0] HSIZE = 3'b0;       // transaction width (max 32-bit supported)
    reg HWRITE = 1'b0;            // write transaction
    reg [31:0] HWDATA = 32'h0;    // write data
    wire [31:0] HRDATA;           // read data from slave
    wire HREADY;             	  // ready signal - to master and to all slaves
    wire HREADYOUT;         	  // ready signal output from this slave

// Outputs from the display block, to the 8-digit display	 
	wire [7:0] digit, segment;     // both active low
	
// Define constants for bus signals and control register addresses
    localparam [2:0] BYTE = 3'b000, HALF = 3'b001, WORD = 3'b010;   // HSIZE values
    localparam [1:0] IDLE = 2'b00, NONSEQ = 2'b10;    // HTRANS values
    localparam [3:0] MODREG = 4'd8, ENBREG = 4'd9;  // address offset
    localparam [31:0] BASEADDR = 32'h5300_0000;     // base address

// Instantiate the display interface block to be tested    
    AHBdisp #(.D_WIDTH (5))  // choose parameter for fast scanning to save time
        dut (
        .HCLK       (HCLK),				
        .HRESETn    (HRESETn),
        .HSEL       (HSELx),
        .HREADY     (HREADY),
        .HADDR      (HADDR),
        .HTRANS     (HTRANS),
        .HWRITE     (HWRITE),  
        .HWDATA     (HWDATA),  
        .HRDATA     (HRDATA),  
        .HREADYOUT  (HREADYOUT),
        .digit      (digit),
        .segment    (segment)
         );

// Generate the clock signal at 50 MHz    
    initial
        begin
            HCLK = 1'b0;
            forever	
                #10 HCLK = ~HCLK;   // invert clock every 10 ns
        end

    initial
        begin
            HRESETn = 1'b1;         // start with reset inactive
            #20 HRESETn = 1'b0;     // start reset on falling edge of clock
            #20 HRESETn = 1'b1;     // end one clock cycle later
            #50;                    // delay before starting tests
            
            AHBwrite(BYTE, BASEADDR+MODREG, 8'h1f);  // digit 4 to 0 will be symbols
            AHBwrite(BYTE, BASEADDR+ENBREG, 8'hdf);  // all enabled except digit 5 
            AHBread (BYTE, BASEADDR+MODREG, 8'h1f);  // read back as bytes to check
            AHBread (BYTE, BASEADDR+ENBREG, 8'hdf); 
            AHBwrite(BYTE, BASEADDR, 8'h1);          // rightmost digit will be 1
            AHBwrite(BYTE, BASEADDR+1, 8'h82);       // digit 1 will be 2.
            AHBwrite(BYTE, BASEADDR+2, 8'h11);       // digit 2 will be -
            AHBwrite(BYTE, BASEADDR+3, 8'hc);        // digit 3 will be c
            AHBwrite(BYTE, BASEADDR+4, 8'h13);       // digit 4 will be H
            AHBwrite(BYTE, BASEADDR+5, 8'haf);       // digit 5 should not display
            AHBwrite(BYTE, BASEADDR+6, 8'h49);       // digit 6 will be 3 horizontal bars
            AHBwrite(BYTE, BASEADDR+7, 8'h36);       // digit 7 will be 2 vertical bars
            AHBread (WORD, BASEADDR, 32'h0c118201);  // read back data as word
            AHBread (WORD, BASEADDR+4, 32'h3649af13);  // read back data as word
            AHBidle;    // put bus in idle state
            #2000;      // delay to see effect of all that
            $stop;            
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
