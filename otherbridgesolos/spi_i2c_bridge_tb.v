`timescale 1ns/1ps

module spi_i2c_bridge_tb;

    reg clk, rst_n;
    reg spi_sclk, spi_mosi, spi_cs_n;
    wire scl, sda;

    // DUT
    spi_i2c_bridge dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .i2c_scl(scl),
        .i2c_sda(sda)
    );

    // Pullups for open-drain
    pullup(scl);
    pullup(sda);

    // Clock
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    // Reset
    initial begin
        rst_n = 0;
        spi_sclk = 0; spi_cs_n = 1; spi_mosi = 0;
        #100 rst_n = 1;
        $display("[%0t] TB: start", $time);
    end

    // SPI master task
    task spi_send_byte(input [7:0] data);
        integer i;
        begin
            spi_cs_n = 0;
            for (i=7; i>=0; i=i-1) begin
                #50 spi_sclk = 0;
                spi_mosi = data[i];
                #50 spi_sclk = 1; // rising edge
            end
            #50 spi_cs_n = 1;
            spi_sclk = 0;
            $display("[%0t] TB: SPI sent 0x%0h", $time, data);
        end
    endtask

    // Test sequence
    initial begin
        #500;
        spi_send_byte(8'hA5);
        #500000;
        $display("[%0t] TB: finished", $time);
        $finish;
    end

    // I2C monitor
    

endmodule
