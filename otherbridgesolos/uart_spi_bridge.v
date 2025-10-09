// uart_spi_bridge.v
// UART -> SPI bridge
// For each UART byte received, transmit it over SPI (MSB first).

`timescale 1ns/1ps

module uart_spi_bridge #(
    parameter integer CLK_FREQ_HZ = 10_000_000,
    parameter integer UART_BAUD   = 115200,
    parameter integer BAUD_DIV    = CLK_FREQ_HZ / UART_BAUD,
    parameter integer SPI_DIV     = 50            // SPI SCLK half-period
)(
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    output wire spi_sclk,
    output wire spi_mosi,
    output wire spi_csn
);

    // -------------------------------
    // UART Receiver
    // -------------------------------
    localparam UART_IDLE  = 2'd0,
               UART_START = 2'd1,
               UART_BITS  = 2'd2,
               UART_STOP  = 2'd3;

    reg [1:0]  uart_state;
    reg [3:0]  bit_cnt;
    reg [7:0]  uart_shift;
    reg [15:0] baud_cnt;
    reg [7:0]  uart_data;
    reg        uart_valid;

    localparam integer HALF_BAUD = BAUD_DIV/2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_state <= UART_IDLE;
            bit_cnt    <= 0;
            baud_cnt   <= 0;
            uart_valid <= 0;
        end else begin
            uart_valid <= 0;
            case (uart_state)
                UART_IDLE: begin
                    if (!uart_rx) begin
                        baud_cnt   <= HALF_BAUD;
                        uart_state <= UART_START;
                    end
                end
                UART_START: begin
                    if (baud_cnt == 0) begin
                        if (!uart_rx) begin
                            baud_cnt   <= BAUD_DIV-1;
                            bit_cnt    <= 0;
                            uart_state <= UART_BITS;
                        end else
                            uart_state <= UART_IDLE;
                    end else baud_cnt <= baud_cnt-1;
                end
                UART_BITS: begin
                    if (baud_cnt == 0) begin
                        uart_shift[bit_cnt] <= uart_rx;
                        if (bit_cnt == 7) begin
                            uart_state <= UART_STOP;
                            baud_cnt   <= BAUD_DIV-1;
                        end else begin
                            bit_cnt  <= bit_cnt+1;
                            baud_cnt <= BAUD_DIV-1;
                        end
                    end else baud_cnt <= baud_cnt-1;
                end
                UART_STOP: begin
                    if (baud_cnt == 0) begin
                        uart_data  <= uart_shift;
                        uart_valid <= 1;
                        uart_state <= UART_IDLE;
                    end else baud_cnt <= baud_cnt-1;
                end
            endcase
        end
    end

    // -------------------------------
    // SPI Master FSM
    // -------------------------------
    localparam SPI_IDLE   = 3'd0,
               SPI_LOAD   = 3'd1,
               SPI_SHIFT0 = 3'd2,
               SPI_SHIFT1 = 3'd3,
               SPI_DONE   = 3'd4;

    reg [2:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_idx;
    reg [15:0] clkdiv;

    reg sclk_reg, mosi_reg, csn_reg;
    assign spi_sclk = sclk_reg;
    assign spi_mosi = mosi_reg;
    assign spi_csn  = csn_reg;

    // clock divider for SPI
    wire tick = (clkdiv==0);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clkdiv <= SPI_DIV-1;
        else if (clkdiv==0)
            clkdiv <= SPI_DIV-1;
        else
            clkdiv <= clkdiv-1;
    end

    // Handshake latch (fix)
    reg spi_start;
    reg [7:0] spi_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_start <= 0;
        end else if (uart_valid) begin
            spi_data  <= uart_data;
            spi_start <= 1;
        end else if (state != SPI_IDLE) begin
            spi_start <= 0;
        end
    end

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= SPI_IDLE;
            sclk_reg <= 0;
            mosi_reg <= 0;
            csn_reg  <= 1;
            bit_idx  <= 0;
            shift_reg<= 0;
        end else if (tick) begin
            case (state)
                SPI_IDLE: begin
                    sclk_reg <= 0;
                    csn_reg  <= 1;
                    if (spi_start) begin
                        shift_reg <= spi_data;
                        bit_idx   <= 7;
                        csn_reg   <= 0; // CS active
                        state     <= SPI_LOAD;
                    end
                end

                SPI_LOAD: begin
                    mosi_reg <= shift_reg[bit_idx];
                    state    <= SPI_SHIFT0;
                end

                // Clock low -> high
                SPI_SHIFT0: begin
                    sclk_reg <= 1;
                    state    <= SPI_SHIFT1;
                end

                // Clock high -> low, move to next bit
                SPI_SHIFT1: begin
                    sclk_reg <= 0;
                    if (bit_idx==0)
                        state <= SPI_DONE;
                    else begin
                        bit_idx <= bit_idx-1;
                        state   <= SPI_LOAD;
                    end
                end

                SPI_DONE: begin
                    csn_reg <= 1;  // deassert CS
                    state   <= SPI_IDLE;
                end
            endcase
        end
    end

endmodule
