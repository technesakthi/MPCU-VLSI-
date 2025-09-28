// mpcu_top.v
// Unified MCU top with two operation modes:
//   controller_en=0 → Bridge mode
//   controller_en=1 → Controller mode

`timescale 1ns/1ps

module mpcu_top #(
    parameter integer CLK_FREQ_HZ = 10_000_000,
    parameter integer UART_BAUD   = 115200
)(
    input  wire clk,
    input  wire rst_n,

    // Mode control
    input  wire        controller_en,   // 1 = controller mode, 0 = bridge mode
    input  wire [1:0]  bridge_mode,     // valid when controller_en=0
    input  wire [1:0]  ctrl_mode,       // valid when controller_en=1
    input  wire        ctrl_start,      // start pulse in controller mode
    input  wire [7:0]  ctrl_data,       // payload for controller mode

    // UART
    input  wire uart_rx,
    output wire uart_tx,

    // SPI
    input  wire spi_sclk_in,
    input  wire spi_mosi_in,
    input  wire spi_csn_in,
    output wire spi_sclk_out,
    output wire spi_mosi_out,
    output wire spi_csn_out,

    // I2C (bidirectional)
    inout  wire i2c_scl,
    inout  wire i2c_sda
);

    // =========================================================
    // BRIDGE MODE SIGNALS
    // =========================================================
    wire us_spi_sclk, us_spi_mosi, us_spi_csn;
    wire ui_scl, ui_sda;
    wire su_uart_tx;
    wire si_scl, si_sda;

    // UART->SPI
    uart_spi_bridge #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .UART_BAUD(UART_BAUD)
    ) u_uart_spi (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .spi_sclk(us_spi_sclk),
        .spi_mosi(us_spi_mosi),
        .spi_csn(us_spi_csn)
    );

    // UART->I2C
    uart_i2c_bridge #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .UART_BAUD(UART_BAUD)
    ) u_uart_i2c (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .i2c_scl(ui_scl),
        .i2c_sda(ui_sda)
    );

    // SPI->UART
    spi_uart_bridge #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .UART_BAUD(UART_BAUD)
    ) u_spi_uart (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk_in),
        .spi_mosi(spi_mosi_in),
        .spi_csn(spi_csn_in),
        .uart_tx(su_uart_tx)
    );

    // SPI->I2C
    spi_i2c_bridge u_spi_i2c (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk_in),
        .spi_mosi(spi_mosi_in),
        .spi_cs_n(spi_csn_in),
        .i2c_scl(si_scl),
        .i2c_sda(si_sda)
    );

    // =========================================================
    // CONTROLLER MODE SIGNALS
    // =========================================================
    wire uart_tx_c;
    wire spi_sclk_c, spi_mosi_c, spi_csn_c;
    wire i2c_scl_c, i2c_sda_c;

    // UART Controller
    uart_controller #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .UART_BAUD(UART_BAUD)
    ) u_uart_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(ctrl_start && controller_en && ctrl_mode==2'b00),
        .data(ctrl_data),
        .tx(uart_tx_c),
        .busy()
    );

    // SPI Controller
    spi_controller #(.SPI_DIV(8)) u_spi_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(ctrl_start && controller_en && ctrl_mode==2'b01),
        .data(ctrl_data),
        .sclk(spi_sclk_c),
        .mosi(spi_mosi_c),
        .spi_csn(spi_csn_c),
        .busy()
    );

    // I2C Controller
    i2c_controller #(.I2C_DIV(50)) u_i2c_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(ctrl_start && controller_en && ctrl_mode==2'b10),
        .data(ctrl_data),
        .scl(i2c_scl_c),
        .sda(i2c_sda_c),
        .busy()
    );

    // =========================================================
    // OUTPUT MUXING
    // =========================================================
    assign spi_sclk_out = controller_en ? 
                          (ctrl_mode==2'b01 ? spi_sclk_c : 1'b0) :
                          (bridge_mode==2'b00 ? us_spi_sclk : 1'b0);

    assign spi_mosi_out = controller_en ? 
                          (ctrl_mode==2'b01 ? spi_mosi_c : 1'b0) :
                          (bridge_mode==2'b00 ? us_spi_mosi : 1'b0);

    assign spi_csn_out  = controller_en ? 
                          (ctrl_mode==2'b01 ? spi_csn_c  : 1'b1) :
                          (bridge_mode==2'b00 ? us_spi_csn : 1'b1);

    assign uart_tx      = controller_en ? 
                          (ctrl_mode==2'b00 ? uart_tx_c : 1'b1) :
                          (bridge_mode==2'b10 ? su_uart_tx : 1'b1);

    assign i2c_scl = controller_en ? 
                     (ctrl_mode==2'b10 ? i2c_scl_c : 1'bz) :
                     (bridge_mode==2'b01 ? ui_scl :
                      bridge_mode==2'b11 ? si_scl : 1'bz);

    assign i2c_sda = controller_en ? 
                     (ctrl_mode==2'b10 ? i2c_sda_c : 1'bz) :
                     (bridge_mode==2'b01 ? ui_sda :
                      bridge_mode==2'b11 ? si_sda : 1'bz);

endmodule
