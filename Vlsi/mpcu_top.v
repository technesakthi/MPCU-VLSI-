`timescale 1ns/1ps
module mpcu_top #(
    parameter integer CLK_FREQ_HZ = 10_000_000,
    parameter integer UART_BAUD   = 115200
)(
    input  wire clk,
    input  wire rst_n,

    // Mode select: 3-bit
    input  wire [2:0] MSEL,        // changed by push button
    input  wire [7:0] ctrl_data,   // data for controller modes

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
    // REGISTER PREVIOUS MSEL TO GENERATE START PULSE FOR CONTROLLERS
    // =========================================================
    reg [2:0] MSEL_d;
    wire start_ctrl;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            MSEL_d <= 3'b000;
        else
            MSEL_d <= MSEL;
    end

    assign start_ctrl = (MSEL != MSEL_d) && (MSEL <= 3'b011); // pulse for controller modes

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
        .start(start_ctrl && MSEL==3'b001),
        .data(ctrl_data),
        .tx(uart_tx_c),
        .busy()
    );

    // SPI Controller
    spi_controller #(.SPI_DIV(8)) u_spi_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_ctrl && MSEL==3'b010),
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
        .start(start_ctrl && MSEL==3'b011),
        .data(ctrl_data),
        .scl(i2c_scl_c),
        .sda(i2c_sda_c),
        .busy()
    );

    // =========================================================
    // OUTPUT MUXING
    // =========================================================
    assign spi_sclk_out = (MSEL==3'b010) ? spi_sclk_c :
                          (MSEL==3'b100 ? us_spi_sclk : 1'b0);
    assign spi_mosi_out = (MSEL==3'b010) ? spi_mosi_c :
                          (MSEL==3'b100 ? us_spi_mosi : 1'b0);
    assign spi_csn_out  = (MSEL==3'b010) ? spi_csn_c :
                          (MSEL==3'b100 ? us_spi_csn : 1'b1);

    assign uart_tx      = (MSEL==3'b001) ? uart_tx_c :
                          (MSEL==3'b110 ? su_uart_tx : 1'b1);

    assign i2c_scl      = (MSEL==3'b011) ? i2c_scl_c :
                           (MSEL==3'b101 ? ui_scl :
                            (MSEL==3'b111 ? si_scl : 1'bz));

    assign i2c_sda      = (MSEL==3'b011) ? i2c_sda_c :
                           (MSEL==3'b101 ? ui_sda :
                            (MSEL==3'b111 ? si_sda : 1'bz));

endmodule
