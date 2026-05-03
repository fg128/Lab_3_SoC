`timescale 1ns / 1ns
/////////////////////////////////////////////////////////////////
// Module Name: TB_AHBspi - testbench for AHBspi block (FIXED)
/////////////////////////////////////////////////////////////////
module TB_AHBspi();

// AHB-Lite Bus Signals
    reg HCLK;
    reg HRESETn;
    reg HSELx = 1'b0;
    reg [31:0] HADDR = 32'h0;
    reg [1:0] HTRANS = 2'b0;
    reg HWRITE = 1'b0;
    reg [2:0] HSIZE = 3'b0;
    reg [31:0] HWDATA = 32'h0;
    wire [31:0] HRDATA;
    wire HREADY;
    wire HREADYOUT;
    wire HRESP;

// SPI signals
    reg  aclMISO = 1'b0;
    wire aclMOSI;
    wire aclSCK;
    wire aclSSn;

// Register to capture what MOSI sends (shift in on rising SCK)
    reg [7:0] mosi_capture = 8'h00;
    integer   mosi_bit     = 7;
    reg       capture_en   = 1'b0;   // gate to ignore stray edges between tests

    localparam [2:0] BYTE = 3'b000, HALF = 3'b001, WORD = 3'b010;
    localparam [1:0] IDLE = 2'b00, NONSEQ = 2'b10;
    localparam [31:0] BASEADDR   = 32'h5200_0000;
    localparam [31:0] DATA_REG   = BASEADDR + 0;
    localparam [31:0] CS_REG     = BASEADDR + 4;
    localparam [31:0] STATUS_REG = BASEADDR + 8;

    AHBspi dut (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn),
        .HSEL       (HSELx),
        .HREADY     (HREADY),
        .HADDR      (HADDR),
        .HTRANS     (HTRANS),
        .HWRITE     (HWRITE),
        .HSIZE      (HSIZE),
        .HWDATA     (HWDATA),
        .HRDATA     (HRDATA),
        .HREADYOUT  (HREADYOUT),
        .HRESP      (HRESP),
        .aclMISO    (aclMISO),
        .aclMOSI    (aclMOSI),
        .aclSCK     (aclSCK),
        .aclSSn     (aclSSn)
    );

    initial begin
        HCLK = 1'b0;
        forever #10 HCLK = ~HCLK;
    end

// Waveform dump for EDA Playground (EPWave) and other VCD viewers.
// EDA Playground requires this to display the waveform — make sure
// the "Open EPWave after run" checkbox is ticked in the run options.
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, TB_AHBspi);
    end

// ===== Waveform-friendly mirrors of the register file =====
// CS_REG, DATA_REG and STATUS_REG are localparams (compile-time addresses),
// so they don't appear in the waveform. These signals show the actual
// register *values* inside the DUT, plus a decoded view of what the bus is
// currently doing. Add these to your EPWave window to see the action.
    wire [7:0] reg_cs_value     = {7'b0, dut.CS};       // CS register contents
    wire [7:0] reg_data_rx      = dut.shift_rx;         // last received SPI byte
    wire [7:0] reg_data_tx      = dut.shift_tx;         // current transmit shift register
    wire [7:0] reg_status_value = {7'b0, dut.busy};     // status register contents

// Decoded label of which register the bus is currently targeting.
// 0 = none, 1 = DATA_REG, 2 = CS_REG, 3 = STATUS_REG
    reg [3:0] bus_reg_select;
    always @(*) begin
        if (HSELx && HTRANS[1]) begin
            case (HADDR[3:2])
                2'h0: bus_reg_select = 4'd1;  // DATA_REG
                2'h1: bus_reg_select = 4'd2;  // CS_REG
                2'h2: bus_reg_select = 4'd3;  // STATUS_REG
                default: bus_reg_select = 4'd0;
            endcase
        end else begin
            bus_reg_select = 4'd0;
        end
    end

// Bus operation: 0=idle, 1=read, 2=write
    reg [1:0] bus_op;
    always @(*) begin
        if (HSELx && HTRANS[1]) bus_op = HWRITE ? 2'd2 : 2'd1;
        else                    bus_op = 2'd0;
    end

// Capture MOSI on every rising SCK edge - only when capture_en is high
    always @(posedge aclSCK) begin
        if (capture_en) begin
            mosi_capture[mosi_bit] = aclMOSI;
            if (mosi_bit > 0) mosi_bit = mosi_bit - 1;
            else              mosi_bit = 7;
        end
    end

// Drive 8 bits onto MISO. The DUT samples MISO on rising SCK edges.
// We set up each bit just after the falling SCK edge so it's stable
// well before the next rising edge.
    task drive_miso_byte;
        input [7:0] data;
        integer i;
        begin
            // Set up MSB before the first rising edge of SCK for this transfer.
            // SCK is currently low (idle), so just set it now.
            aclMISO = data[7];
            // For bits 6..0: wait for the falling edge that follows each rising
            // edge, then set up the next bit. After the loop, 7 falling edges
            // have been seen, meaning 7 rising edges were used to sample bits
            // 7..1. We then wait one more falling edge so bit 0 has been
            // sampled on the rising edge before it.
            for (i = 6; i >= 0; i = i - 1) begin
                @(negedge aclSCK);
                #5 aclMISO = data[i];
            end
            // Wait for the final falling edge -- this is the one that follows
            // the rising edge that sampled bit 0.
            @(negedge aclSCK);
        end
    endtask

// Wait for the DUT to finish a transfer (busy bit goes low).
// First wait for busy to go high (the FSM may need a cycle to enter SHIFT
// after the start signal), then wait for it to go low again.
    task wait_busy_clear;
        integer timeout;
        begin
            timeout = 0;
            while (!dut.busy && timeout < 50) begin
                @(posedge HCLK);
                timeout = timeout + 1;
            end
            timeout = 0;
            while (dut.busy && timeout < 5000) begin
                @(posedge HCLK);
                timeout = timeout + 1;
            end
            // Small settling delay so the FSM definitely returns to IDLE
            repeat(3) @(posedge HCLK);
        end
    endtask

// ===================== Test Sequence =====================
    initial begin
        HRESETn = 1'b1;
        #20 HRESETn = 1'b0;
        #20 HRESETn = 1'b1;
        #50;

        // --- Test 1: reset state ---
        AHBread(BYTE, CS_REG,     8'h1);
        AHBread(BYTE, STATUS_REG, 8'h0);
        AHBidle;
        $display("Test 1 (reset state): errCount = %0d", errCount);

        // --- Test 2: CS register write/read ---
        AHBwrite(BYTE, CS_REG, 8'h0);
        AHBread (BYTE, CS_REG, 8'h0);
        AHBidle;
        #20;
        $display("Test 2 (CS register): errCount = %0d, aclSSn = %b (expect 0)", errCount, aclSSn);

        // --- Test 3: Transfer 0xA5, receive 0x3C ---
        mosi_bit     = 7;
        mosi_capture = 8'h00;
        capture_en   = 1'b1;

        AHBwrite(BYTE, DATA_REG, 8'hA5);      // write A5 to be shifted out from shift_tx
        AHBidle;                              // release bus so DUT sees start only once
        drive_miso_byte(8'h3C);               // setup 3C to be shifted into shift_rx
        wait_busy_clear;
        capture_en = 1'b0;

        AHBread(BYTE, STATUS_REG, 8'h0);      // check transaction is over and busy bit is zero
        AHBread(BYTE, DATA_REG,   8'h3c);     // check we have received the 3C from shift_rx
        AHBidle;
        $display("Test 3 (transfer 0xA5 rx 0x3C): errCount = %0d", errCount);
        $display("  MOSI captured: 0x%02X (expect 0xA5)", mosi_capture);

        // --- Test 4: Deassert CS ---
        AHBwrite(BYTE, CS_REG, 8'h1);        // Write CS back to one
        AHBread (BYTE, CS_REG, 8'h1);        // Check CS has been wrote successfully
        AHBidle;
        #20;
        $display("Test 4 (CS deassert): errCount = %0d, aclSSn = %b (expect 1)", errCount, aclSSn);

        // --- Test 5: Transfer 0xFF, receive 0x55 ---
        AHBwrite(BYTE, CS_REG, 8'h0);       // write CS back to zero to start transaction
        AHBidle;
        #20;
        mosi_bit     = 7;
        mosi_capture = 8'h00;
        capture_en   = 1'b1;

        AHBwrite(BYTE, DATA_REG, 8'hFF);    // write FF to be shifted out from shift_tx
        AHBidle;
        drive_miso_byte(8'h55);             // setup 55 to be shifted into shift_rx
        wait_busy_clear;
        capture_en = 1'b0;

        AHBread(BYTE, STATUS_REG, 8'h0);    // check busy bit is done
        AHBread(BYTE, DATA_REG,   8'h55);   // check we have received the 55 from shift_rx
        AHBidle;
        $display("Test 5 (transfer 0xFF rx 0x55): errCount = %0d", errCount);
        $display("  MOSI captured: 0x%02X (expect 0xFF)", mosi_capture);

        // --- Test 6: Transfer with CS deasserted ---
        AHBwrite(BYTE, CS_REG, 8'h1);       // write CS back to 1 to indicate no transaction
        AHBidle;
        #20;
        mosi_bit     = 7;
        mosi_capture = 8'h00;
        capture_en   = 1'b1;

        AHBwrite(BYTE, DATA_REG, 8'hAA);   // write A5 to be shifted out from shift_tx
        AHBidle;
        drive_miso_byte(8'h00);            // setup 00 to be shifted into shift_rx
        wait_busy_clear;
        capture_en = 1'b0;

        AHBread(BYTE, STATUS_REG, 8'h0);   // check busy bit is done
        AHBidle;
        $display("Test 6 (transfer with CS high): errCount = %0d", errCount);
        $display("  MOSI captured: 0x%02X (expect 0xAA - SCK still runs)", mosi_capture);

        #100;
        $display("=== All tests complete. Total errors: %0d ===", errCount);
        $finish;
    end


// =========== AHB bus tasks ===========

    reg [31:0] nextWdata    = 32'h0;
    reg [31:0] expectRdata  = 32'h0;
    reg [31:0] rExpectRead;
    reg [4:0]  rReadType;
    reg        checkRead;
    reg [31:0] readCapture  = 32'h0;
    reg        transState;
    reg        error        = 1'b0;
    integer    errCount     = 0;

    task AHBwrite (
            input [2:0] size,
            input [31:0] addr,
            input [31:0] data );
        begin
            wait (HREADY == 1'b1);
            @ (posedge HCLK);
            #1 HSIZE = size;
            HTRANS = NONSEQ;
            HWRITE = 1'b1;
            HADDR  = addr;
            HSELx  = 1'b1;
            #1;
            case ({size, addr[1:0]})
              5'b000_00: nextWdata = data & 8'hff;
              5'b000_01: nextWdata = (data & 8'hff) << 8;
              5'b000_10: nextWdata = (data & 8'hff) << 16;
              5'b000_11: nextWdata = (data & 8'hff) << 24;
              5'b001_00: nextWdata = data & 16'hffff;
              5'b001_10: nextWdata = (data & 16'hffff) << 16;
              5'b010_00: nextWdata = data;
              default:   nextWdata = 32'hdeadbeef;
            endcase
        end
    endtask

    task AHBread (
            input [2:0] size,
            input [31:0] addr,
            input [31:0] data );
        begin
            wait (HREADY == 1'b1);
            @ (posedge HCLK);
            #1 HSIZE = size;
            HTRANS = NONSEQ;
            HWRITE = 1'b0;
            HADDR  = addr;
            HSELx  = 1'b1;
            #1 expectRdata = data;
        end
    endtask

    task AHBidle;
        begin
            wait (HREADY == 1'b1);
            @ (posedge HCLK);
            #1 HTRANS = IDLE;
            HSELx = 1'b0;
        end
    endtask

    always @ (posedge HCLK)
        if (~HRESETn) HWDATA <= 32'b0;
        else if (HSELx && HWRITE && HTRANS && HREADY)
            #1 HWDATA <= nextWdata;
        else if (HREADY)
            #1 HWDATA <= {HADDR[31:24], HADDR[11:0], 12'hbad};

    always @ (posedge HCLK)
        if (~HRESETn) begin
            rExpectRead <= 32'b0; rReadType <= 5'b0; checkRead <= 1'b0;
        end else if (HSELx && ~HWRITE && HTRANS && HREADY) begin
            if      (HSIZE == 3'b0) rExpectRead <= expectRdata & 8'hff;
            else if (HSIZE == 3'b1) rExpectRead <= expectRdata & 16'hffff;
            else                    rExpectRead <= expectRdata;
            rReadType <= {HSIZE, HADDR[1:0]};
            checkRead <= 1'b1;
        end else if (HREADY)
            checkRead <= 1'b0;

    always @ (posedge HCLK)
        if (~HRESETn) error <= 1'b0;
        else if (checkRead & HREADY) begin
            case (rReadType)
              5'b000_00: readCapture = HRDATA & 8'hff;
              5'b000_01: readCapture = (HRDATA >> 8)  & 8'hff;
              5'b000_10: readCapture = (HRDATA >> 16) & 8'hff;
              5'b000_11: readCapture = (HRDATA >> 24) & 8'hff;
              5'b001_00: readCapture = HRDATA & 16'hffff;
              5'b001_10: readCapture = (HRDATA >> 16) & 16'hffff;
              default:   readCapture = HRDATA;
            endcase
            if (readCapture != rExpectRead) begin
                error    <= 1'b1;
                errCount  = errCount + 1;
                $display("READ ERROR at time %0t: got 0x%08X, expected 0x%08X", $time, readCapture, rExpectRead);
            end else error <= 1'b0;
        end else error <= 1'b0;

    always @ (posedge HCLK)
        if (~HRESETn) transState <= 1'b0;
        else if (HSELx && HTRANS && HREADY) #1 transState <= 1'b1;
        else if (HREADY)                    #1 transState <= 1'b0;

    assign HREADY = transState ? HREADYOUT : 1'b1;

endmodule
