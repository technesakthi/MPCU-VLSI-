`timescale 1ns/1ps

module tb_mpcu_top_full;

    // Clock & Reset
    reg clk;
    reg rst_n;
    reg controller_en;
    reg [1:0] bridge_mode;
    reg [1:0] ctrl_mode;
    reg ctrl_start;
    reg [7:0] ctrl_data;

    reg  uart_rx;
    wire uart_tx;

    reg  spi_sclk_in, spi_mosi_in, spi_csn_in;
    wire spi_sclk_out, spi_mosi_out, spi_csn_out;


    wire i2c_scl, i2c_sda;

    always #5 clk = ~clk;

  
    mpcu_top #(
        .CLK_FREQ_HZ(100_000_000),
        .UART_BAUD(115200)
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

   
    pullup(i2c_scl);
    pullup(i2c_sda);

   
    localparam CLK_FREQ_HZ = 100_000_000;
    localparam UART_BAUD   = 115200;
    localparam BIT_PERIOD  = 1_000_000_000 / UART_BAUD; 


    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx <= 0; #(BIT_PERIOD);  
            for (i=0; i<8; i=i+1) begin
                uart_rx <= data[i];
                #(BIT_PERIOD);
            end
            uart_rx <= 1; #(BIT_PERIOD);  
            $display("[%0t] TB: UART sent 0x%0h", $time, data);
        end
    endtask

    // SPI send task (for SPI->UART/I2C bridge tests)
    task spi_send_byte(input [7:0] data);
        integer i;
        begin
            spi_csn_in = 0;
            for (i=7; i>=0; i=i-1) begin
                #50 spi_sclk_in = 0;
                spi_mosi_in = data[i];
                #50 spi_sclk_in = 1;
            end
            #50 spi_csn_in = 1;
            spi_sclk_in = 0;
            $display("[%0t] TB: SPI sent 0x%0h", $time, data);
        end
    endtask

    // Main stimulus
    initial begin
      
        // Default state
        clk = 0;
        rst_n = 0;
        controller_en = 0;
       
        ctrl_mode = 2'b00;
        ctrl_start = 0;
        ctrl_data = 8'h00;
        uart_rx = 1; // idle
        spi_sclk_in = 0;
        spi_mosi_in = 0;
        spi_csn_in  = 1;

        // Reset
        #200;
        rst_n = 1;
        $display("[%0t] TB: Reset complete", $time);

        // =====================================================
        // CONTROLLER MODE TESTS
        // =====================================================
        controller_en = 1;

        // UART controller send
        $display("\n=== Controller Mode: UART ===");
        ctrl_mode  = 2'b00;  // UART
        ctrl_data  = 8'hA5;
        ctrl_start = 1;
        repeat (5) @(posedge clk);  // hold long enough
        ctrl_start = 0;
        #200000; // wait full UART frame

        // SPI controller send
        $display("\n=== Controller Mode: SPI ===");
        ctrl_mode  = 2'b01;  // SPI
        ctrl_data  = 8'h3C;
        ctrl_start = 1;
        repeat (5) @(posedge clk);
        ctrl_start = 0;
        #200000;

        // I2C controller send
        $display("\n=== Controller Mode: I2C ===");
        ctrl_mode  = 2'b10;  // I2C
        ctrl_data  = 8'h55;
        ctrl_start = 1;
        repeat (5) @(posedge clk);
        ctrl_start = 0;
        #200000;

        // =====================================================
        // BRIDGE MODE TESTS
        // =====================================================
        controller_en = 0;
        ctrl_data = 8'h00;
         bridge_mode = 2'b00;
         ctrl_mode = 2'b00;

        // UART -> SPI
        $display("\n=== Bridge Mode: UART -> SPI ===");
        bridge_mode = 2'b00;
        #(10*BIT_PERIOD);
        uart_send_byte(8'hA5);
        #(20*BIT_PERIOD);
    
        // UART -> I2C
        $display("\n=== Bridge Mode: UART -> I2C ===");
        bridge_mode = 2'b01;
        #(10*BIT_PERIOD);
        uart_send_byte(8'h55);
        #(20*BIT_PERIOD);
    

        // SPI -> UART
        $display("\n=== Bridge Mode: SPI -> UART ===");
        bridge_mode = 2'b10;
        spi_send_byte(8'hA5);
        #500000;
      

        // SPI -> I2C
        $display("\n=== Bridge Mode: SPI -> I2C ===");
        bridge_mode = 2'b11;
        spi_send_byte(8'h55);
        #500000;
       
        $display("\n=== TEST COMPLETE ===");
        $finish;
    end

endmodule
