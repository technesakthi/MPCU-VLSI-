`timescale 1ns/1ps

module tb_mpcu_controller;

    reg clk, rst_n, start;
    reg [1:0] mode;
    reg [7:0] data_in;

    wire uart_tx;
    wire spi_sclk, spi_mosi, spi_csn;
    wire i2c_scl, i2c_sda;

    // DUT
    mpcu_controller_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .start(start),
        .data_in(data_in),
        .uart_tx(uart_tx),
        .spi_sclk_out(spi_sclk),
        .spi_mosi_out(spi_mosi),
        .spi_csn_out(spi_csn),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    // clock
    always #5 clk = ~clk;

    // I2C pullups
    pullup(i2c_scl);
    pullup(i2c_sda);

    initial begin
        $dumpfile("tb_mpcu_controller.vcd");
        $dumpvars(0, tb_mpcu_controller);

        clk = 0;
        rst_n = 0;
        start = 0;
        mode = 2'b00;
        data_in = 8'h00;

        #50 rst_n = 1;

        // UART test
        #50 mode = 2'b00; data_in = 8'hA5; start = 1;
        #10 start = 0;

        // wait
        #20000;

        // SPI test
        mode = 2'b01; data_in = 8'h3C; start = 1;
        #10 start = 0;

        #20000;

        // I2C test
        mode = 2'b10; data_in = 8'h7E; start = 1;
        #10 start = 0;

        #5000;

        $finish;
    end

endmodule
