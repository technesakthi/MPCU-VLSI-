# genus_synth.tcl
# Example Cadence Genus synthesis script for mpcu_top
# Edit variable SRCS to include all your verilog files (relative paths)

# ---------------------
# user config
# ---------------------
set DESIGN mpcu_top

# list source files (edit these paths to match your project layout)
set SRCS {
    src/mpcu_top.v
    src/uart_spi_bridge.v
    src/uart_i2c_bridge.v
    src/spi_uart_bridge.v
    src/spi_i2c_bridge.v
    src/uart_controller.v
    src/spi_controller.v
    src/i2c_controller.v
    src/uart_rx.v
    src/fifo.v
    # add any other modules here...
}

set CONSTRAINTS mpcu_constraints.sdc

# ---------------------
# start Genus session (example)
# ---------------------
reset_design

# read all verilog files
foreach f $SRCS {
    if {![file exists $f]} {
        puts "WARNING: source file not found: $f"
    } else {
        read_verilog $f
    }
}

# set top
elaborate $DESIGN
link_design $DESIGN

# read SDC constraints
if {[file exists $CONSTRAINTS]} {
    read_sdc $CONSTRAINTS
} else {
    puts "WARNING: constraints file $CONSTRAINTS not found"
}

# create clock (redundant if in SDC but harmless)
create_clock -period 10.0 -name clk [get_ports clk]

# run synthesis/compile
compile

# generate reports & outputs
write_verilog -hierarchy -output synthesized_netlist.v
write_sdf -output ${DESIGN}.sdf
report_timing > timing_report.txt
report_area > area_report.txt
report_power > power_report.txt

puts "Genus synthesis finished. Check synthesized_netlist.v, ${DESIGN}.sdf, timing_report.txt"
