// uart_i2c_bridge.v
// UART -> I2C bridge (1 UART byte => 1 I2C packet)
// Packet format: START + SLAVE_ADDR (fixed) + WRITE + DATA + ACK + STOP

`timescale 1ns/1ps

module uart_i2c_bridge #(
    parameter integer CLK_FREQ_HZ = 10_000_000,    // system clock
    parameter integer UART_BAUD   = 115200,        // UART baud
    parameter integer BAUD_DIV    = CLK_FREQ_HZ / UART_BAUD,
    parameter integer I2C_DIV     = 50,            // SCL half-period in clk cycles
    parameter [6:0]   SLAVE_ADDR  = 7'h42          // fixed I2C slave address
)(
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    inout  wire i2c_scl,
    inout  wire i2c_sda
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
                        uart_data  <= uart_shift; // correctly assembled LSB->MSB
                        uart_valid <= 1;
                        uart_state <= UART_IDLE;
                    end else baud_cnt <= baud_cnt-1;
                end
            endcase
        end
    end

    // -------------------------------
    // I2C Master FSM
    // -------------------------------
    reg scl_oen, sda_oen;
    assign i2c_scl = (scl_oen==0) ? 1'b0 : 1'bz;
    assign i2c_sda = (sda_oen==0) ? 1'b0 : 1'bz;

    localparam I2C_IDLE       = 4'd0,
               I2C_START      = 4'd1,
               I2C_ADDR_BIT   = 4'd2,
               I2C_ADDR_HIGH  = 4'd3,
               I2C_ADDR_ACK0  = 4'd4,
               I2C_ADDR_ACK1  = 4'd5,
               I2C_DATA_BIT   = 4'd6,
               I2C_DATA_HIGH  = 4'd7,
               I2C_DATA_ACK0  = 4'd8,
               I2C_DATA_ACK1  = 4'd9,
               I2C_STOP0      = 4'd10,
               I2C_STOP1      = 4'd11;

    reg [3:0] state;
    reg [7:0] tx_byte;
    reg [3:0] bit_idx;
    reg [15:0] clkdiv;
    reg [7:0] uart_latch;
    reg start_tx;

    // latch UART data when valid
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            start_tx <= 0;
        else if (uart_valid) begin
            uart_latch <= uart_data;
            start_tx   <= 1;
        end else if (state!=I2C_IDLE)
            start_tx <= 0;
    end

    // I2C clock divider (generate ticks)
    wire tick = (clkdiv==0);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clkdiv <= I2C_DIV-1;
        else if (clkdiv==0)
            clkdiv <= I2C_DIV-1;
        else
            clkdiv <= clkdiv-1;
    end

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= I2C_IDLE;
            scl_oen <= 1;
            sda_oen <= 1;
            bit_idx <= 0;
            tx_byte <= 0;
        end else if (tick) begin
            case (state)
                I2C_IDLE: begin
                    scl_oen <= 1; sda_oen <= 1;
                    if (start_tx) state <= I2C_START;
                end

                I2C_START: begin
                    scl_oen <= 1; sda_oen <= 0;   // START
                    tx_byte <= {SLAVE_ADDR,1'b0};
                    bit_idx <= 7;
                    state   <= I2C_ADDR_BIT;
                end

                // Address bits
                I2C_ADDR_BIT: begin
                    scl_oen <= 0;
                    sda_oen <= tx_byte[bit_idx] ? 1 : 0;
                    state   <= I2C_ADDR_HIGH;
                end
                I2C_ADDR_HIGH: begin
                    scl_oen <= 1;
                    if (bit_idx==0)
                        state <= I2C_ADDR_ACK0;
                    else begin
                        bit_idx <= bit_idx-1;
                        state   <= I2C_ADDR_BIT;
                    end
                end

                // ACK after address
                I2C_ADDR_ACK0: begin
                    scl_oen <= 0; sda_oen <= 1;  // release SDA
                    state   <= I2C_ADDR_ACK1;
                end
                I2C_ADDR_ACK1: begin
                    scl_oen <= 1;                // sample ACK
                    tx_byte <= uart_latch;       // <-- FIX: load data directly (MSB first)
                    bit_idx <= 7;
                    state   <= I2C_DATA_BIT;
                end

                // Data bits
                I2C_DATA_BIT: begin
                    scl_oen <= 0;
                    sda_oen <= tx_byte[bit_idx] ? 1 : 0;
                    state   <= I2C_DATA_HIGH;
                end
                I2C_DATA_HIGH: begin
                    scl_oen <= 1;
                    if (bit_idx==0)
                        state <= I2C_DATA_ACK0;
                    else begin
                        bit_idx <= bit_idx-1;
                        state   <= I2C_DATA_BIT;
                    end
                end

                // ACK after data
                I2C_DATA_ACK0: begin
                    scl_oen <= 0; sda_oen <= 1;
                    state   <= I2C_DATA_ACK1;
                end
                I2C_DATA_ACK1: begin
                    scl_oen <= 1;
                    state   <= I2C_STOP0;
                end

                // STOP
                I2C_STOP0: begin
                    scl_oen <= 1; sda_oen <= 0;
                    state   <= I2C_STOP1;
                end
                I2C_STOP1: begin
                    scl_oen <= 1; sda_oen <= 1;  // STOP
                    state   <= I2C_IDLE;
                end
            endcase
        end
    end

endmodule
