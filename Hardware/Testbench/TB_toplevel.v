`timescale 1ns / 1ns
/////////////////////////////////////////////////////////////////
// Module Name: TB_toplevel
// Simple testbench for SoC - no program load, just clock and reset
/////////////////////////////////////////////////////////////////
module TB_toplevel(    );
     
    reg btnCpuResetn, clk100, btnU; 
    reg [15:0] sw;		// switch inputs
    wire [15:0] LED;
    wire serialRx = 1'b1;		// serial receive at idle
    wire serialTx;        		// serial transmit
     
    AHBliteTop dut(
        .clk100(clk100), 
        .btnCpuResetn(btnCpuResetn),
        .btnU(btnU),
        .serialRx(serialRx),
        .sw(sw),
        .led(LED), 
        .serialTx(serialTx)
         );
         
 
    initial
        begin
            clk100 = 1'b0;
            forever     // generate 100 MHz clock
                #5 clk100 = ~clk100;  // invert clock every 5 ns
        end

    initial
        begin
            sw = 16'h5a4b;			// set a value on the switches
            btnCpuResetn = 1'b1;		// start with reset inactive
            btnU = 1'b0;				// loader button not pressed
            #400;         // wait for cpu and bus clock to be stable 
            btnCpuResetn = 1'b0;    // active low reset
            #30 btnCpuResetn = 1'b1;    // release reset
            #20000;      // delay 20 us or 500 cpu clock cycles
            $stop;
        end

endmodule
