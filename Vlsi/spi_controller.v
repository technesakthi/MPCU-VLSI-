`timescale 1ns/1ps
module spi_controller #(
    parameter integer SPI_DIV = 4   // number of sysclk cycles per half-SCLK; tune for simulation
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire [7:0] data,
    output reg  sclk,
    output reg  mosi,
    output reg  spi_csn,
    output reg  busy
);
    reg [7:0] shift;
    reg [3:0] bit_idx;
    reg [15:0] clk_div;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_csn <= 1;
            sclk <= 0;
            mosi <= 0;
            busy <= 0;
            shift <= 0;
            bit_idx <= 0;
            clk_div <= 0;
        end else begin
            if (start && !busy) begin
                spi_csn <= 0;           // assert CS
                shift <= data;
                bit_idx <= 7;
                busy <= 1;
                clk_div <= SPI_DIV - 1;
                sclk <= 0;
                mosi <= data[7];       // drive first bit BEFORE clock starts
            end else if (busy) begin
                if (clk_div == 0) begin
                    clk_div <= SPI_DIV - 1;
                    if (sclk == 0) begin
                        // rising edge
                        sclk <= 1;
                    end else begin
                        // falling edge -> prepare next bit while clock is low
                        sclk <= 0;
                        if (bit_idx == 0) begin
                            // last bit was shifted, finish
                            spi_csn <= 1;
                            busy <= 0;
                        end else begin
                            bit_idx <= bit_idx - 1;
                            mosi <= shift[bit_idx - 1];
                        end
                    end
                end else begin
                    clk_div <= clk_div - 1;
                end
            end
        end
    end
endmodule