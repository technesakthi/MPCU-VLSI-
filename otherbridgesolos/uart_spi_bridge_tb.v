// uart_spi_bridge_tb.v
`timescale 1ns/1ps

module uart_spi_bridge_tb;

    reg clk, rst_n, uart_rx;
    wire spi_sclk, spi_mosi, spi_csn;

    // DUT
    uart_spi_bridge #(
        .CLK_FREQ_HZ(10_000_000),
        .UART_BAUD  (115200),
        .SPI_DIV    (50)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_csn(spi_csn)
    );

    // -------------------------------
    // Clock and Reset
    // -------------------------------
    initial clk = 0;
    always #50 clk = ~clk;   // 10 MHz

    initial begin
        rst_n = 0;
        uart_rx = 1;
        #1000;
        rst_n = 1;
    end

    // -------------------------------
    // UART Stimulus
    // -------------------------------
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx <= 0; #(8680); // start bit
            for (i=0; i<8; i=i+1) begin
                uart_rx <= data[i];
                #(8680);
            end
            uart_rx <= 1; #(8680); // stop bit
        end
    endtask

    initial begin
        @(posedge rst_n);
        #20000;
        $display("[%0t] Sending UART bytes...", $time);
        uart_send_byte(8'hA5);
        uart_send_byte(8'h3C);
        uart_send_byte(8'h7E);
        #200000;
        $finish;
    end

    // -------------------------------
    // SPI Monitor / Decoder
    // -------------------------------
    reg [7:0] spi_shift;
    integer spi_bitcnt;

    initial begin
        spi_shift  = 0;
        spi_bitcnt = 0;
    end

    // Capture MOSI on rising edge of SCLK while CSN is low
    always @(posedge spi_sclk) begin
        if (!spi_csn) begin
            spi_shift <= {spi_shift[6:0], spi_mosi};
            spi_bitcnt <= spi_bitcnt + 1;

            if (spi_bitcnt == 7) begin
                $display("[%0t] SPI: Byte received = 0x%02h",
                         $time, {spi_shift[6:0], spi_mosi});
                spi_bitcnt <= 0;
            end
        end
    end

    // -------------------------------
    // VCD Dump
    // -------------------------------
    initial begin
        $dumpfile("uart_spi_bridge_tb.vcd");
        $dumpvars(0, uart_spi_bridge_tb);
    end

endmodule
