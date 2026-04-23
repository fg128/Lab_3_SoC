proc start_step { step } {
  set stopFile ".stop.rst"
  if {[file isfile .stop.rst]} {
    puts ""
    puts "*** Halting run - EA reset detected ***"
    puts ""
    puts ""
    return -code error
  }
  set beginFile ".$step.begin.rst"
  set platform "$::tcl_platform(platform)"
  set user "$::tcl_platform(user)"
  set pid [pid]
  set host ""
  if { [string equal $platform unix] } {
    if { [info exist ::env(HOSTNAME)] } {
      set host $::env(HOSTNAME)
    }
  } else {
    if { [info exist ::env(COMPUTERNAME)] } {
      set host $::env(COMPUTERNAME)
    }
  }
  set ch [open $beginFile w]
  puts $ch "<?xml version=\"1.0\"?>"
  puts $ch "<ProcessHandle Version=\"1\" Minor=\"0\">"
  puts $ch "    <Process Command=\".planAhead.\" Owner=\"$user\" Host=\"$host\" Pid=\"$pid\">"
  puts $ch "    </Process>"
  puts $ch "</ProcessHandle>"
  close $ch
}

proc end_step { step } {
  set endFile ".$step.end.rst"
  set ch [open $endFile w]
  close $ch
}

proc step_failed { step } {
  set endFile ".$step.error.rst"
  set ch [open $endFile w]
  close $ch
}

set_msg_config -id {HDL 9-1061} -limit 100000
set_msg_config -id {HDL 9-1654} -limit 100000
set_msg_config  -id {Synth 8-312}  -suppress 
set_msg_config  -id {IP_Flow 19-3664}  -suppress 

start_step write_bitstream
set rc [catch {
  create_msg_db write_bitstream.pb
  debug::add_scope template.lib 1
  open_checkpoint AHBliteTop_routed.dcp
  set_property webtalk.parent_dir C:/Users/lab/Documents/EmbeddedSystems/FG_DB_PB_SoC/DES_SoC/Hardware/DemoSystem.cache/wt [current_project]
  write_bitstream -force AHBliteTop.bit 
  catch { write_sysdef -hwdef AHBliteTop.hwdef -bitfile AHBliteTop.bit -meminfo AHBliteTop.mmi -ltxfile debug_nets.ltx -file AHBliteTop.sysdef }
  close_msg_db -file write_bitstream.pb
} RESULT]
if {$rc} {
  step_failed write_bitstream
  return -code error $RESULT
} else {
  end_step write_bitstream
}

