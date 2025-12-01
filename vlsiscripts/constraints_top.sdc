# CLOCK: 10 MHz => 100 ns period
create_clock -name clk -period 100 -waveform {0 50} [get_ports "clk"]

# Clock transition (example 0.1 ns)
set_clock_transition -rise 0.1 [get_clocks "clk"]
set_clock_transition -fall 0.1 [get_clocks "clk"]

# Clock uncertainty
set_clock_uncertainty 0.01 [get_ports "clk"]

# ===== Input Delays =====
set_input_delay -max 1.0 [get_ports "rst_n"]  -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "uart_rx"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "spi_mosi_in"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "spi_sclk_in"] -clock [get_clocks "clk"]

# For control signals
set_input_delay -max 1.0 [get_ports "MSEL"]     -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "ctrl_data"] -clock [get_clocks "clk"]

# ===== Output Delays =====
set_output_delay -max 1.0 [get_ports "uart_tx"]     -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "spi_mosi_out"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "spi_sclk_out"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "spi_csn_out"]  -clock [get_clocks "clk"]

# I2C inouts (treated like outputs)
set_output_delay -max 1.0 [get_ports "i2c_scl"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "i2c_sda"] -clock [get_clocks "clk"]
