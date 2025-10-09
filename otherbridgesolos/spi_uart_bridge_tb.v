`timescale 1ns/1ps

module spi_uart_bridge_tb;

    // Parameters
    localparam CLK_FREQ_HZ = 10_000_000;
    localparam UART_BAUD   = 115200;
    localparam BAUD_DIV    = CLK_FREQ_HZ / UART_BAUD;

    // Clock
    reg clk;
    initial clk = 0;
    always #50 clk = ~clk; // 10 MHz sys clk (100 ns period)

    // DUT signals
    reg rst_n;
    reg spi_sclk, spi_mosi, spi_csn;
    wire uart_tx;

    // Instantiate DUT
    spi_uart_bridge #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .UART_BAUD(UART_BAUD)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_csn(spi_csn),
        .uart_tx(uart_tx)
    );

    // SPI master task to send 1 byte MSB first
    task spi_send_byte(input [7:0] data);
        integer i;
        begin
            spi_csn = 0;
            for (i=7; i>=0; i=i-1) begin
                // Setup MOSI
                spi_mosi = data[i];
                // Toggle clock
                #200 spi_sclk = 1;  // rising edge
                #200 spi_sclk = 0;  // falling edge
            end
            spi_csn = 1;
        end
    endtask

    // UART monitor task
    task monitor_uart;
        integer i;
        reg [9:0] frame;
        begin
            // Wait for start bit (low)
            @(negedge uart_tx);
            frame[0] = 0; // start
            // Sample each bit at baud rate
            #(BAUD_DIV*100); // half-bit wait
            for (i=1; i<10; i=i+1) begin
                #(BAUD_DIV*100);
                frame[i] = uart_tx;
            end
            $display("[%0t] UART frame = %b (data=%02h)", $time, frame, frame[8:1]);
        end
    endtask

    // Stimulus
    initial begin
        $display("[%0t] TB: start", $time);
        rst_n    = 0;
        spi_sclk = 0;
        spi_mosi = 0;
        spi_csn  = 1;
        #500;
        rst_n = 1;

        // Send one SPI byte (0xA5)
        #1000;
        $display("[%0t] TB: Sending SPI byte 0xA5", $time);
        spi_send_byte(8'hA5);

        // Monitor UART response
        monitor_uart();

        #100000;
        $display("[%0t] TB: finished", $time);
        $finish;
    end

endmodule
