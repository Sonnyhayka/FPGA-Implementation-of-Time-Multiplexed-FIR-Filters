set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir .. ..]]
set result_dir [file join $root result]
set part xc7a35tcpg236-1
file mkdir $result_dir

set rtl_files [list \
    [file join $script_dir fixed_point_mac.sv] \
    [file join $script_dir fixed_point_output.sv] \
    [file join $script_dir coeff_bram.sv] \
    [file join $script_dir fir_delay_line.sv] \
    [file join $script_dir fir_time_mux_controller.sv] \
    [file join $script_dir fir_time_mux_top.sv]]

foreach mode {0 1} {
    foreach rtl_file $rtl_files {
        read_verilog -sv [list $rtl_file]
    }
    read_mem [list [file join $root data h_q115_packed.txt]]
    cd [file join $root data]
    synth_design -top fir_time_mux_top -part $part -mode out_of_context -generic SRL_REG=$mode -generic N=64 -generic M=4
    create_clock -name clk -period 20.000 [get_ports clk]
    opt_design
    report_utilization -file [file join $result_dir utilization_srl${mode}.rpt]
    report_utilization -format xml -file [file join $result_dir utilization_srl${mode}.xml]
    report_timing_summary -file [file join $result_dir timing_srl${mode}.rpt]
    write_checkpoint -force [file join $result_dir fir_time_mux_srl${mode}.dcp]
    close_design
}

exit
