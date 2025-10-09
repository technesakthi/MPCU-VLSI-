`timescale 1ns/1ps

module tb_mpcu_all;

    // ==========================
    // Clock and Reset
    // ==========================
    reg clk;
    reg rst_n;

    // ==========================
    // Control / Mode Signals
    // ==========================
    reg controller_en;
    reg [1:0] bridge_mode;
    reg [1:0] ctrl_mode;
    reg ctrl_start;
    reg [7:0] ctrl_data;

    // ==========================
    // Communication Interfaces
    // ==========================
    reg  uart_rx;
    wire uart_tx;

    reg  spi_sclk_in, spi_mosi_in, spi_csn_in;
    wire spi_sclk_out, spi_mosi_out, spi_csn_out;

    wire i2c_scl, i2c_sda;

    // ==========================
    // Parameters
    // ==========================
    localparam CLK_FREQ_HZ = 100_000_000;
    localparam UART_BAUD   = 115200;
    localparam BIT_PERIOD  = 1_000_000_000 / UART_BAUD; // ns per bit

    // ==========================
    // Clock Generation
    // ==========================
    always #5 clk = ~clk;  // 100 MHz

    // ==========================
    // DUT
    // ==========================
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

    // ==========================
    // I2C Pullups
    // ==========================
    pullup(i2c_scl);
    pullup(i2c_sda);

    // ==========================
    // Tasks
    // ==========================
    // UART Send Task
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx <= 0; #(BIT_PERIOD); // Start bit
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx <= data[i]; #(BIT_PERIOD);
            end
            uart_rx <= 1; #(BIT_PERIOD); // Stop bit
            $display("[%0t] UART TX <- 0x%0h", $time, data);
        end
    endtask

    // SPI Send Task
    task spi_send_byte(input [7:0] data);
        integer i;
        begin
            spi_csn_in = 0;
            for (i = 7; i >= 0; i = i - 1) begin
                #50 spi_sclk_in = 0;
                spi_mosi_in = data[i];
                #50 spi_sclk_in = 1;
            end
            #50 spi_csn_in = 1;
            spi_sclk_in = 0;
            $display("[%0t] SPI TX <- 0x%0h", $time, data);
        end
    endtask

    // ==========================
    // Initialization
    // ==========================
    initial begin
     

        clk = 0;
        rst_n = 0;

        controller_en = 0;
        bridge_mode   = 2'b00;
        ctrl_mode     = 2'b00;
        ctrl_start    = 0;
        ctrl_data     = 8'h00;
        uart_rx       = 1;
        spi_sclk_in   = 0;
        spi_mosi_in   = 0;
        spi_csn_in    = 1;

        #100;
        rst_n = 1;
        $display("[%0t] Reset done", $time);
    end

    // ==========================
    // Test Sequence
    // ==========================
    initial begin
        // ======================
        // Controller Mode Tests
        // ======================
        controller_en = 1;
        $display("\n=== CONTROLLER MODE ===");

        // UART Controller
        @(posedge clk);
        ctrl_mode = 2'b00;
        ctrl_data = 8'hA5;
        ctrl_start = 1; @(posedge clk); ctrl_start = 0;
        #100000;

        // SPI Controller
        @(posedge clk);
        ctrl_mode = 2'b01;
        ctrl_data = 8'h3C;
        ctrl_start = 1; @(posedge clk); ctrl_start = 0;
        #100000;

        // I2C Controller
        @(posedge clk);
        ctrl_mode = 2'b10;
        ctrl_data = 8'h7E;
        ctrl_start = 1; @(posedge clk); ctrl_start = 0;
        #200000;
        ctrl_data     = 8'h00;

        // ======================
        // UART Bridge Tests
        // ======================
        controller_en = 0;
        $display("\n=== UART BRIDGE MODE ===");

        // UART → SPI
        bridge_mode = 2'b00;
        #(10*BIT_PERIOD);
        uart_send_byte(8'hA5);
        #(20*BIT_PERIOD);
       
        // UART → I2C
        bridge_mode = 2'b01;
        #(10*BIT_PERIOD);
        uart_send_byte(8'h55);
        #(200*BIT_PERIOD);
       
        // ======================
        // SPI Bridge Tests
        // ======================
        $display("\n=== SPI BRIDGE MODE ===");

        // SPI → UART
        bridge_mode = 2'b10;
        spi_send_byte(8'hA5);
        #50000;
    

        // SPI → I2C
        bridge_mode = 2'b11;
        spi_send_byte(8'h55);
        #50000;
     

        $display("\n=== TEST COMPLETE ===");
        #100000;
        $finish;
    end

endmodule
