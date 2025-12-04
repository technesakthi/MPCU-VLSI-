create_clock -name clk -period 10 [get_ports clk]
set_clock_transition -rise 0.1 [get_clocks clk]
set_clock_transition -fall 0.1 [get_clocks clk]
set_clock_uncertainty 0.02 [get_ports clk]

set_input_delay -max 1 [get_ports rst_n] -clock clk
set_input_delay -max 1 [get_ports uart_rx] -clock clk
set_input_delay -max 1 [get_ports spi_mosi_in] -clock clk
set_input_delay -max 1 [get_ports spi_sclk_in] -clock clk
set_input_delay -max 1 [get_ports MSEL] -clock clk
set_input_delay -max 1 [get_ports ctrl_data] -clock clk

set_output_delay -max 1 [get_ports uart_tx] -clock clk
set_output_delay -max 1 [get_ports spi_mosi_out] -clock clk
set_output_delay -max 1 [get_ports spi_sclk_out] -clock clk
set_output_delay -max 1 [get_ports spi_csn_out] -clock clk
set_output_delay -max 1 [get_ports i2c_scl] -clock clk
set_output_delay -max 1 [get_ports i2c_sda] -clock clk
