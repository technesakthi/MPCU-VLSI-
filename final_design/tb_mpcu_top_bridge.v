`timescale 1ns/1ps

module tb_mpcu_top_bridge;

    // Clock & Reset
    reg clk;
    reg rst_n;

    // Mode control
    reg controller_en;
    reg [1:0] bridge_mode;
    reg [1:0] ctrl_mode;
    reg ctrl_start;
    reg [7:0] ctrl_data;

    // UART
    reg  uart_rx;
    wire uart_tx;

    // SPI
    reg  spi_sclk_in, spi_mosi_in, spi_csn_in;
    wire spi_sclk_out, spi_mosi_out, spi_csn_out;

    // I2C
    wire i2c_scl, i2c_sda;

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    // Parameters
    localparam CLK_FREQ_HZ = 100_000_000;
    localparam UART_BAUD   = 115200;
    localparam BIT_PERIOD  = 1_000_000_000 / UART_BAUD; // ns per UART bit

    // DUT
    mpcu_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .UART_BAUD(UART_BAUD)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .controller_en(controller_en),
        .bridge_mode(bridge_mode),
        .ctrl_mode(ctrl_mode),
        .ctrl_start(ctrl_start),
        .ctrl_data(ctrl_data),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .spi_sclk_in(spi_sclk_in),
        .spi_mosi_in(spi_mosi_in),
        .spi_csn_in(spi_csn_in),
        .spi_sclk_out(spi_sclk_out),
        .spi_mosi_out(spi_mosi_out),
        .spi_csn_out(spi_csn_out),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    // I2C pullups
    pullup(i2c_scl);
    pullup(i2c_sda);

    // UART send task (8N1)
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx <= 0; #(BIT_PERIOD);   // start bit
            for (i=0; i<8; i=i+1) begin
                uart_rx <= data[i]; #(BIT_PERIOD);
            end
            uart_rx <= 1; #(BIT_PERIOD);   // stop bit
        end
    endtask

    initial begin
        $dumpfile("tb_mpcu_top_bridge.vcd");
        $dumpvars(0, tb_mpcu_top_bridge);

        // Default values
        clk = 0;
        rst_n = 0;
        controller_en = 0; // Bridge mode
        bridge_mode = 2'b00;
        ctrl_mode = 2'b00;
        ctrl_start = 0;
        ctrl_data = 8'h00;
        uart_rx = 1;   // idle
        spi_sclk_in = 0;
        spi_mosi_in = 0;
        spi_csn_in  = 1;

        // Reset
        #100;
        rst_n = 1;

        // ==================================
        // Bridge Mode: UART -> SPI
        // ==================================
        $display("=== UART -> SPI Test ===");
        bridge_mode = 2'b00;   // UART->SPI
        #(10*BIT_PERIOD);
        uart_send_byte(8'hA5); // send 0xA5
        #(20*BIT_PERIOD);
        uart_send_byte(8'h3C); 
        #(50*BIT_PERIOD);

        // ==================================
        // Bridge Mode: UART -> I2C
        // ==================================
        $display("=== UART -> I2C Test ===");
        bridge_mode = 2'b01;   // UART->I2C
        #(10*BIT_PERIOD);
        uart_send_byte(8'hA5); 
        #(200*BIT_PERIOD);
        uart_send_byte(8'h3C); 
        #(200*BIT_PERIOD);

        // Finish
        #(1000*BIT_PERIOD);
        $finish;
    end

endmodule
