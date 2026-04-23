@echo off
set xv_path=C:\\Xilinx\\Vivado\\2015.2\\bin
call %xv_path%/xsim TB_AHBdisp_behav -key {Behavioral:sim_disp:Functional:TB_AHBdisp} -tclbatch TB_AHBdisp.tcl -view C:/Users/lab/Documents/EmbeddedSystems/FG_DB_PB_SoC/DES_SoC/Hardware/TB_AHBdisp_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
