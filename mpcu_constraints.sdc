# mpcu_constraints.sdc
# SDC constraints for mpcu_top
# Generated for: CLK = 100 MHz (10.0 ns period)
# Assumptions: asynchronous reset rst_n, input_delay=2.0 ns, output_delay=3.0 ns

# -------------------------
# design top
# -------------------------
set_top mpcu_top

# -------------------------
# primary clock
# -------------------------
create_clock -name clk -period 10.0 -waveform {0.0 5.0} [get_ports clk]
# small uncertainty (skew/jitter) — adjust if you know system jitter
set_clock_uncertainty 0.1 [get_clocks]

# -------------------------
# I/O timing (external interface)
# adjust input/output delays if you have measured values
# -------------------------
# Inputs to design (arrive relative to clk)
set_input_delay -clock clk 2.0 [get_ports {uart_rx spi_sclk_in spi_mosi_in spi_csn_in}]
# Outputs from design (launch relative to clk)
set_output_delay -clock clk 3.0 [get_ports {uart_tx spi_sclk_out spi_mosi_out spi_csn_out}]

# I2C lines are bidirectional/open-drain — model as outputs for launch checks,
# and inputs for capture checks. Use conservative constraints here.
set_output_delay -clock clk 3.0 [get_ports {i2c_scl i2c_sda}]
set_input_delay  -clock clk 2.0 [get_ports {i2c_scl i2c_sda}]

# -------------------------
# asynchronous reset
# -------------------------
# rst_n is active-low asynchronous reset
# tell tool not to timecheck paths from reset (make false path)
set_false_path -from [get_ports rst_n] -to [get_clocks]
# Also don't do timing on reset release (tool can infer), but keep this simple:
set_false_path -from [get_ports rst_n]

# -------------------------
# clock groups (single clock here)
# -------------------------
# if you later add other independent clocks, use set_clock_groups to define relations

# -------------------------
# Optional: IO standard / drive strength / input delay sources
# (Left as comments: fill according to your board / I/O standard)
# Example (if using a particular IO cell):
# set_driving_cell -libcell {IOBUF} -pin {O} [get_ports uart_rx]
# set_load 0.1 [get_ports uart_tx]   ;# load in pF
# -------------------------

# -------------------------
# synthesis/timing quality-of-life
# -------------------------
# prefer registers for timing optimization (optional)
# set_max_transition -from [get_registers] -to [get_registers] 0.5

# -------------------------
# end of file
# -------------------------
