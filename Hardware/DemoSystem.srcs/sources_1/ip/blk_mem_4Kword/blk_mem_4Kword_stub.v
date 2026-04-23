// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.2 (win64) Build 1266856 Fri Jun 26 16:35:25 MDT 2015
// Date        : Thu Apr 02 13:08:05 2026
// Host        : Eleclab85 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               C:/Users/lab/Documents/EmbeddedSystems/FG_DB_PB_SoC/DES_SoC/Hardware/DemoSystem.srcs/sources_1/ip/blk_mem_4Kword/blk_mem_4Kword_stub.v
// Design      : blk_mem_4Kword
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_2,Vivado 2015.2" *)
module blk_mem_4Kword(clka, wea, addra, dina, clkb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,wea[3:0],addra[11:0],dina[31:0],clkb,addrb[11:0],doutb[31:0]" */;
  input clka;
  input [3:0]wea;
  input [11:0]addra;
  input [31:0]dina;
  input clkb;
  input [11:0]addrb;
  output [31:0]doutb;
endmodule
