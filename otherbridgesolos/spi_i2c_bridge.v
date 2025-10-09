// spi_i2c_bridge.v
// SPI -> I2C bridge (1 SPI byte => 1 I2C packet)
// Packet: START + SLAVE_ADDR (fixed) + WRITE + DATA + ACKs + STOP

`timescale 1ns/1ps

module spi_i2c_bridge #(
    parameter integer I2C_DIV     = 50,      // I2C SCL half-period in clk cycles
    parameter [6:0]   SLAVE_ADDR  = 7'h42    // fixed I2C slave address
)(
    input  wire clk,
    input  wire rst_n,

    // SPI slave interface (mode-0)
    input  wire spi_sclk,
    input  wire spi_mosi,
    input  wire spi_cs_n,

    // I2C interface (open-drain)
    inout  wire i2c_scl,
    inout  wire i2c_sda
);

    // -------------------------------
    // SPI Slave (8-bit shift register)
    // -------------------------------
    reg [7:0] spi_shift;
    reg [2:0] spi_cnt;
    reg       spi_sclk_d;
    reg       spi_latch_valid;
    reg [7:0] spi_latch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_shift       <= 0;
            spi_cnt         <= 0;
            spi_sclk_d      <= 0;
            spi_latch_valid <= 0;
        end else begin
            spi_sclk_d <= spi_sclk;

            if (!spi_cs_n) begin
                // detect rising edge of SCLK
                if (spi_sclk && !spi_sclk_d) begin
                    spi_shift <= {spi_shift[6:0], spi_mosi};
                    spi_cnt   <= spi_cnt + 1;
                    if (spi_cnt == 3'd7) begin
                        spi_latch       <= {spi_shift[6:0], spi_mosi};
                        spi_latch_valid <= 1;
                        spi_cnt         <= 0;
                    end
                end
            end else begin
                spi_cnt <= 0;
            end
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
    reg [7:0] data_buf;
    reg       start_tx;

    // latch SPI byte into buffer when ready
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            start_tx <= 0;
        else if (spi_latch_valid) begin
            data_buf  <= spi_latch;
            start_tx  <= 1;
            spi_latch_valid <= 0;
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
                    tx_byte <= data_buf;         // load SPI data
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
