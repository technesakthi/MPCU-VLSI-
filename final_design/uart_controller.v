`timescale 1ns/1ps

// uart_controller.v
module uart_controller #(
    parameter integer CLK_FREQ_HZ = 10_000_000,
    parameter integer UART_BAUD   = 100_000   // chosen so BAUD_DIV = integer with 10MHz
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire [7:0] data,
    output reg  tx,
    output reg  busy
);
    localparam integer BAUD_DIV = CLK_FREQ_HZ / UART_BAUD;

    reg [9:0] frame;         // {stop, data[7:0], start}
    reg [3:0] bit_idx;       // 0..9
    reg [15:0] baud_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx <= 1'b1; // idle high
            busy <= 1'b0;
            frame <= 10'b1111111111;
            bit_idx <= 0;
            baud_cnt <= 0;
        end else begin
            if (start && !busy) begin
                frame <= {1'b1, data, 1'b0}; // stop(1), data[7:0], start(0)
                bit_idx <= 0;
                baud_cnt <= BAUD_DIV - 1;
                busy <= 1'b1;
                tx <= 1'b0; // start immediately for visibility (will be sampled for BAUD_DIV cycles)
            end else if (busy) begin
                if (baud_cnt == 0) begin
                    bit_idx <= bit_idx + 1;
                    if (bit_idx == 9) begin
                        // finished last bit just outputted; go idle
                        busy <= 1'b0;
                        tx <= 1'b1;
                    end else begin
                        tx <= frame[bit_idx+1]; // next bit
                        baud_cnt <= BAUD_DIV - 1;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 1;
                end
            end
        end
    end
endmodule

