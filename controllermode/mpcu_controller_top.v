`timescale 1ns/1ps

module mpcu_controller_top #(
    parameter integer CLK_FREQ_HZ = 10_000_000,
    parameter integer UART_BAUD   = 100_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] mode,      // 00=UART,01=SPI,10=I2C
    input  wire start,           // pulse to send data_in
    input  wire [7:0] data_in,

    output wire uart_tx,
    output wire spi_sclk_out,
    output wire spi_mosi_out,
    output wire spi_csn_out,
    inout  wire i2c_scl,
    inout  wire i2c_sda
);

    // UART
    wire uart_busy;
    uart_controller #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .UART_BAUD  (UART_BAUD)
    ) u_uart_ctrl (
        .clk(clk), .rst_n(rst_n),
        .start(start && mode==2'b00),
        .data(data_in),
        .tx(uart_tx),
        .busy(uart_busy)
    );

    // SPI
    wire spi_sclk_c, spi_mosi_c, spi_csn_c, spi_busy;
    spi_controller #(.SPI_DIV(8)) u_spi_ctrl (
        .clk(clk), .rst_n(rst_n),
        .start(start && mode==2'b01),
        .data(data_in),
        .sclk(spi_sclk_c),
        .mosi(spi_mosi_c),
        .spi_csn(spi_csn_c),
        .busy(spi_busy)
    );

    // I2C
    wire i2c_busy;
    i2c_controller #(.I2C_DIV(50)) u_i2c_ctrl (
        .clk(clk), .rst_n(rst_n),
        .start(start && mode==2'b10),
        .data(data_in),
        .scl(i2c_scl),
        .sda(i2c_sda),
        .busy(i2c_busy)
    );

    // Output muxing: if not selected, leave lines idle
    assign spi_sclk_out = (mode==2'b01) ? spi_sclk_c : 1'b0;
    assign spi_mosi_out = (mode==2'b01) ? spi_mosi_c : 1'b0;
    assign spi_csn_out  = (mode==2'b01) ? spi_csn_c  : 1'b1;
    // uart_tx is already idle=1 when unused

endmodule
