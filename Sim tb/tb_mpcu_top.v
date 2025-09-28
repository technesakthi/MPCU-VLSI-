`timescale 1ns/1ps

module tb_mpcu_top;

    // Clock & Reset
    reg clk;
    reg rst_n;

    // Mode control
    reg controller_en;
    reg [1:0] bridge_mode;
    reg [1:0] ctrl_mode;
    reg ctrl_start;
    reg [7:0] ctrl_data;

    // UART
    reg  uart_rx;
    wire uart_tx;

    // SPI
    reg  spi_sclk_in, spi_mosi_in, spi_csn_in;
    wire spi_sclk_out, spi_mosi_out, spi_csn_out;

    // I2C
    wire i2c_scl, i2c_sda;

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    // DUT
    mpcu_top #(
        .CLK_FREQ_HZ(100_000_000),
        .UART_BAUD(115200)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .controller_en(controller_en),
        .bridge_mode(bridge_mode),
        .ctrl_mode(ctrl_mode),
        .ctrl_start(ctrl_start),
        .ctrl_data(ctrl_data),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .spi_sclk_in(spi_sclk_in),
        .spi_mosi_in(spi_mosi_in),
        .spi_csn_in(spi_csn_in),
        .spi_sclk_out(spi_sclk_out),
        .spi_mosi_out(spi_mosi_out),
        .spi_csn_out(spi_csn_out),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    // I2C pullups
    pullup(i2c_scl);
    pullup(i2c_sda);

    initial begin
        $dumpfile("tb_mpcu_top.vcd");
        $dumpvars(0, tb_mpcu_top);

        // Default values
        clk = 0;
        rst_n = 0;
        controller_en = 0;
        bridge_mode = 2'b00;
        ctrl_mode = 2'b00;
        ctrl_start = 0;
        ctrl_data = 8'h00;
        uart_rx = 1;   // idle
        spi_sclk_in = 0;
        spi_mosi_in = 0;
        spi_csn_in  = 1;

        // Reset
        #100;
        rst_n = 1;

        // ==================================
        // Controller Mode: UART send 0xA5
        // ==================================
        @(posedge clk);
        controller_en = 1;
        ctrl_mode = 2'b00;   // UART
        ctrl_data = 8'hA5;
        ctrl_start = 1;
        @(posedge clk);
        ctrl_start = 0;

        #100000;  // wait UART transmission

        // ==================================
        // Controller Mode: SPI send 0x3C
        // ==================================
        @(posedge clk);
        ctrl_mode = 2'b01;   // SPI
        ctrl_data = 8'hA5;
        ctrl_start = 1;
        @(posedge clk);
        ctrl_start = 0;

        #100000;  // wait SPI transmission

        // ==================================
        // Controller Mode: I2C send 0x7E
        // ==================================
        @(posedge clk);
        ctrl_mode = 2'b10;   // I2C
        ctrl_data = 8'hA5;
        ctrl_start = 1;
        @(posedge clk);
        ctrl_start = 0;

        #100000;  // wait I2C transmission

        $finish;
    end

endmodule
