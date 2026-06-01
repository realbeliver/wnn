create_clock [ get_ports "clk"] -name sample_clk -period [expr $::env(CLOCK_PERIOD)]
create_clock [ get_ports "uio_in\[3\]"] -name spi_clk -period [expr $::env(CLOCK_PERIOD)]

set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_PCT) ]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_PCT) ]
set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]

set cap_load [ expr $::env(OUTPUT_CAP_LOAD) / 1000.0]

set idx [ lsearch [ all_inputs ] “clk” ]
set all_inputs_wo_clk [ lreplace [ all_inputs ] $idx $idx ]
set idx [ lsearch $all_inputs_wo_clk “uio_in\[3\]” ]
set all_inputs_wo_clk [ lreplace $all_inputs_wo_clk $idx $idx ]

set idx [lsearch [ all_inputs] [get_ports "clk"]]
set all_sample_inputs_wo_clk  [lreplace [ all_inputs ] $idx $idx]
set idx [lsearch $all_sample_inputs_wo_clk [get_ports "uio_in\[0\]"] ]
set all_sample_inputs [lreplace $all_sample_inputs_wo_clk $idx $idx]
set idx [lsearch $all_sample_inputs [get_ports "uio_in\[1\]"] ]
set all_sample_inputs_2 [lreplace $all_sample_inputs $idx $idx]
set idx [lsearch $all_sample_inputs_2 [get_ports "uio_in\[2\]"] ]
set all_sample_inputs_3 [lreplace $all_sample_inputs_2 $idx $idx]
set idx [lsearch $all_sample_inputs_3 [get_ports "uio_in\[3\]"] ]
set all_sample_inputs_4 [lreplace $all_sample_inputs_3 $idx $idx]
set idx [lsearch $all_sample_inputs_4 [get_ports "uio_in\[4\]"] ]
set all_sample_inputs_5 [lreplace $all_sample_inputs_4 $idx $idx]
set idx [lsearch $all_sample_inputs_5 [get_ports "uio_in\[5\]"] ]
set all_sample_inputs_6 [lreplace $all_sample_inputs_5 $idx $idx]
set idx [lsearch $all_sample_inputs_6 [get_ports "uio_in\[6\]"] ]
set all_sample_inputs_7 [lreplace $all_sample_inputs_6 $idx $idx]
set idx [lsearch $all_sample_inputs_7 [get_ports "uio_in\[7\]"] ]
set all_sample_inputs_8 [lreplace $all_sample_inputs_7 $idx $idx]

set idx [lsearch [ all_inputs] [ get_ports "clk" ]]
set all_spi_wo_clk  [lreplace [all_inputs] $idx $idx]
set idx [lsearch $all_spi_wo_clk [ get_ports  "ui_in\[0\]"] ]
set all_spi_inputs_2 [lreplace $all_spi_wo_clk $idx $idx]
set idx [lsearch $all_spi_inputs_2 [ get_ports "ui_in\[1\]"] ]
set all_spi_inputs_3 [lreplace $all_spi_inputs_2 $idx $idx]
set idx [lsearch $all_spi_inputs_3 [ get_ports  "ui_in\[2\]"] ]
set all_spi_inputs_4 [lreplace $all_spi_inputs_3 $idx $idx]
set idx [lsearch $all_spi_inputs_4 [ get_ports "ui_in\[3\]"] ]
set all_spi_inputs_5 [lreplace $all_spi_inputs_4 $idx $idx]
set idx [lsearch $all_spi_inputs_5 [ get_ports  "ui_in\[4\]"] ]
set all_spi_inputs_6 [lreplace $all_spi_inputs_5 $idx $idx]
set idx [lsearch $all_spi_inputs_6 [ get_ports  "ui_in\[5\]"] ]
set all_spi_inputs_7 [lreplace $all_spi_inputs_6 $idx $idx]
set idx [lsearch $all_spi_inputs_7 [ get_ports  "ui_in\[6\]"] ]
set all_spi_inputs_8 [lreplace $all_spi_inputs_7 $idx $idx]
set idx [lsearch $all_spi_inputs_8 [ get_ports  "ui_in\[7\]"] ]
set all_spi_inputs_9 [lreplace $all_spi_inputs_8 $idx $idx]
set idx [lsearch $all_spi_inputs_9 [ get_ports "uio_in\[3\]"] ]
set all_spi_inputs_10 [lreplace $all_spi_inputs_9 $idx $idx]

set idx [lsearch [ all_outputs] "uio_out"]
set all_sample_outputs  [lreplace [ all_outputs ] $idx $idx]

set idx [lsearch [ all_outputs] "uo_out"]
set all_spi_outputs  [lreplace [ all_outputs ] $idx $idx]

set_input_delay $input_delay_value -clock [get_clocks sample_clk] [get_ports $all_sample_inputs_8]
set_input_delay $input_delay_value -clock [get_clocks spi_clk] [get_ports $all_spi_inputs_10]

set_output_delay $output_delay_value -clock [get_clocks sample_clk] $all_sample_outputs
set_output_delay $output_delay_value -clock [get_clocks spi_clk] $all_spi_outputs

set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [get_clocks sample_clk]
set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [get_clocks spi_clk]

set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks sample_clk]
set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks spi_clk]

set_clock_groups -asynchronous -group {sample_clk} -group {spi_clk}

set_driving_cell -lib_cell $::env(SYNTH_DRIVING_CELL) -pin $::env(SYNTH_DRIVING_CELL_PIN) $all_inputs_wo_clk
set_load  $cap_load [ all_outputs ]
set_timing_derate -early [ expr {1-$::env(SYNTH_TIMING_DERATE)} ]
set_timing_derate -late [ expr {1+$::env(SYNTH_TIMING_DERATE)} ]

#puts [ get_clocks sample_clk ]
#puts [ get_clocks spi_clk ]
#puts [ all_clocks ]
#puts [ all_inputs ]
#puts [ get_ports $all_sample_inputs_8 ]
#puts [ get_ports $all_spi_inputs_10 ]



