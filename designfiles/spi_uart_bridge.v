// spi_uart_bridge.v
// SPI slave -> UART transmitter
// Captures 1 byte from SPI MOSI and sends over UART

`timescale 1ns/1ps

module spi_uart_bridge #(
    parameter integer CLK_FREQ_HZ = 10_000_000,
    parameter integer UART_BAUD   = 115200,
    parameter integer BAUD_DIV    = CLK_FREQ_HZ / UART_BAUD
)(
    input  wire clk,
    input  wire rst_n,

    // SPI slave interface
    input  wire spi_sclk,
    input  wire spi_mosi,
    input  wire spi_csn,

    // UART output
    output wire uart_tx
);

    // -------------------------------
    // SPI Slave Receiver
    // -------------------------------
    reg [7:0] spi_shift;
    reg [2:0] bit_cnt;
    reg       byte_ready;
    reg       spi_sclk_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_shift   <= 0;
            bit_cnt     <= 0;
            byte_ready  <= 0;
            spi_sclk_d  <= 0;
        end else begin
            spi_sclk_d <= spi_sclk;

            if (!spi_csn) begin
                // Detect rising edge of SCLK (mode 0)
                if (!spi_sclk_d && spi_sclk) begin
                    spi_shift <= {spi_shift[6:0], spi_mosi};
                    if (bit_cnt == 7) begin
                        bit_cnt    <= 0;
                        byte_ready <= 1;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end else begin
                bit_cnt <= 0;
            end

            // Clear flag when UART picks it up
            if (byte_ready && uart_busy == 0)
                byte_ready <= 0;
        end
    end

    // -------------------------------
    // UART Transmitter
    // -------------------------------
    reg [3:0] uart_state;
    reg [15:0] baud_cnt;
    reg [3:0] bit_index;
    reg uart_reg;
    reg [9:0] uart_shift;

    assign uart_tx = uart_reg;
    reg uart_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_state <= 0;
            uart_reg   <= 1;  // idle line = high
            uart_busy  <= 0;
            baud_cnt   <= 0;
            bit_index  <= 0;
        end else begin
            case (uart_state)
                0: begin
                    if (byte_ready && !uart_busy) begin
                        // load {stop(1), data, start(0)}
                        uart_shift <= {1'b1, spi_shift, 1'b0};
                        uart_busy  <= 1;
                        uart_state <= 1;
                        baud_cnt   <= BAUD_DIV-1;
                        bit_index  <= 0;
                    end
                end
                1: begin
                    if (baud_cnt == 0) begin
                        uart_reg <= uart_shift[bit_index];
                        baud_cnt <= BAUD_DIV-1;
                        if (bit_index == 9) begin
                            uart_state <= 0;
                            uart_busy  <= 0;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else baud_cnt <= baud_cnt - 1;
                end
            endcase
        end
    end

endmodule
