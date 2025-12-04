set_db init_lib_search_path /home/install/FOUNDRY/digital/90nm/lib/
set_db library slow.lib

read_hdl {./mpcu_top.v ./uart_controller.v ./spi_controller.v ./i2c_controller.v \
          ./uart_spi_bridge.v ./spi_uart_bridge.v ./spi_i2c_bridge.v ./uart_i2c_bridge.v}

elaborate mpcu_top
read_sdc ./constraints_top.sdc

set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

syn_generic
syn_map
syn_opt

file mkdir reports

report_timing -max_paths 10 > reports/timing_report.rpt
report_area > reports/area_report.rpt
report_power > reports/power_report.rpt
report_constraints > reports/constraints_report.rpt
report_clock > reports/clock_report.rpt
report_gates > reports/gate_report.rpt
check_design > reports/check_design_report.rpt

write_hdl > mpcu_top_netlist.v
write_sdc > mpcu_top_tool.sdc

puts "SYNTHESIS COMPLETE"
