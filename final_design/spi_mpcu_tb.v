`timescale 1ns/1ps

module spi_mpcu_tb;

    reg clk, rst_n;

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

    // DUT
    mpcu_top dut (
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

    // Pullups for open-drain I2C
    pullup(i2c_scl);
    pullup(i2c_sda);

    // Clock
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    // Reset
    initial begin
        rst_n = 0;
        controller_en = 0;  // bridge mode
        bridge_mode   = 2'b00;
        ctrl_mode     = 2'b00;
        ctrl_start    = 0;
        ctrl_data     = 8'h00;
        uart_rx       = 1;
        spi_sclk_in   = 0;
        spi_mosi_in   = 0;
        spi_csn_in    = 1;
        #100 rst_n = 1;
        $display("[%0t] TB: Reset done", $time);
    end

    // SPI master send task (mode0, MSB first)
    task spi_send_byte(input [7:0] data);
        integer i;
        begin
            spi_csn_in = 0;
            for (i=7; i>=0; i=i-1) begin
                #50 spi_sclk_in = 0;
                spi_mosi_in = data[i];
                #50 spi_sclk_in = 1;
            end
            #50 spi_csn_in = 1;
            spi_sclk_in = 0;
            $display("[%0t] TB: SPI sent 0x%0h", $time, data);
        end
    endtask

    // Test sequence
    initial begin
        #500;

        // ==============================
        // SPI -> UART Test
        // ==============================
        $display("[%0t] TB: SPI->UART test start", $time);
        bridge_mode = 2'b10; // SPI->UART
        spi_send_byte(8'hA5);
        #20000;
        spi_send_byte(8'h3C);
        #50000;

        // ==============================
        // SPI -> I2C Test
        // ==============================
        $display("[%0t] TB: SPI->I2C test start", $time);
        bridge_mode = 2'b11; // SPI->I2C
        spi_send_byte(8'h55);
        #50000;
        spi_send_byte(8'h7E);
        #50000;

        $display("[%0t] TB: finished", $time);
        $finish;
    end

endmodule
