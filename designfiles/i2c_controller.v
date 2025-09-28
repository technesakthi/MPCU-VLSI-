// i2c_controller.v
// Simple I2C Master Controller: sends one byte on start pulse
// Format: START + SLAVE_ADDR + WRITE + DATA + STOP

`timescale 1ns/1ps

module i2c_controller #(
    parameter integer I2C_DIV    = 50,       // SCL half-period in clk cycles
    parameter [6:0]   SLAVE_ADDR = 7'h42     // fixed I2C slave address
)(
    input  wire clk,
    input  wire rst_n,

    input  wire start,           // 1-cycle pulse to start transfer
    input  wire [7:0] data,      // byte to send

    inout  wire scl,             // open-drain
    inout  wire sda,             // open-drain
    output reg  busy
);

    // -------------------------------
    // Open-drain drivers
    // -------------------------------
    reg scl_oen, sda_oen;
    assign scl = (scl_oen==0) ? 1'b0 : 1'bz;
    assign sda = (sda_oen==0) ? 1'b0 : 1'bz;

    // -------------------------------
    // Start latch (prevents pulse loss)
    // -------------------------------
    reg start_latched;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            start_latched <= 0;
        else if (start)
            start_latched <= 1;          // capture request
        else if (state != I2C_IDLE)
            start_latched <= 0;          // clear once FSM leaves IDLE
    end

    // -------------------------------
    // FSM states
    // -------------------------------
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

    // -------------------------------
    // Clock divider -> tick generator
    // -------------------------------
    wire tick = (clkdiv==0);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clkdiv <= I2C_DIV-1;
        else if (clkdiv==0)
            clkdiv <= I2C_DIV-1;
        else
            clkdiv <= clkdiv-1;
    end

    // -------------------------------
    // FSM
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= I2C_IDLE;
            scl_oen <= 1;
            sda_oen <= 1;
            bit_idx <= 0;
            tx_byte <= 0;
            busy    <= 0;
        end else if (tick) begin
            case (state)
                I2C_IDLE: begin
                    scl_oen <= 1; 
                    sda_oen <= 1;
                    busy    <= 0;
                    if (start_latched) begin
                        state   <= I2C_START;
                        busy    <= 1;
                    end
                end

                I2C_START: begin
                    scl_oen <= 1; 
                    sda_oen <= 0;   // START
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
                    scl_oen <= 0; 
                    sda_oen <= 1;  // release SDA
                    state   <= I2C_ADDR_ACK1;
                end
                I2C_ADDR_ACK1: begin
                    scl_oen <= 1;                // sample ACK
                    tx_byte <= data;             // load DATA byte
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
                    scl_oen <= 0; 
                    sda_oen <= 1;
                    state   <= I2C_DATA_ACK1;
                end
                I2C_DATA_ACK1: begin
                    scl_oen <= 1;
                    state   <= I2C_STOP0;
                end

                // STOP
                I2C_STOP0: begin
                    scl_oen <= 1; 
                    sda_oen <= 0;
                    state   <= I2C_STOP1;
                end
                I2C_STOP1: begin
                    scl_oen <= 1; 
                    sda_oen <= 1;  // STOP
                    state   <= I2C_IDLE;
                end
            endcase
        end
    end

endmodule
