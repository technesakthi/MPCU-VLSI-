`timescale 1ns/1ps
module tb_mpcu_top_pushbtn;

    // =========================
    // Clock, Reset, Button
    // =========================
    reg clk;
    reg rst_n;
    reg push_btn;
    reg [7:0] ctrl_data;

    // UART
    reg  uart_rx;
    wire uart_tx;

    // SPI
    reg  spi_sclk_in, spi_mosi_in, spi_csn_in;
    wire spi_sclk_out, spi_mosi_out, spi_csn_out;

    // I2C
    wire i2c_scl, i2c_sda;

    always #5 clk = ~clk;  // 100 MHz

    // =========================
    // DUT instantiation
    // =========================
    wire [2:0] MSEL;
    mpcu_top #(
        .CLK_FREQ_HZ(100_000_000),
        .UART_BAUD(115200)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .MSEL(MSEL),
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

    // Open-drain pullups for I2C
    pullup(i2c_scl);
    pullup(i2c_sda);

    // =========================
    // Push-button MSEL logic
    // =========================
    reg [2:0] mode_reg;
    reg push_btn_d;
    assign MSEL = mode_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg   <= 3'b000;
            push_btn_d <= 0;
        end else begin
            push_btn_d <= push_btn;
            if (push_btn & ~push_btn_d) begin
                mode_reg <= mode_reg + 1;  // increment on rising edge
                $display("[%0t] TB: Push button pressed → MSEL=%b", $time, mode_reg+1);
            end
        end
    end

    // =========================
    // SPI send task
    // =========================
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

    // =========================
    // UART send task
    // =========================
    localparam UART_BAUD = 115200;
    localparam BIT_PERIOD = 1_000_000_000 / UART_BAUD; // ns

    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx <= 0; #(BIT_PERIOD); // start bit
            for (i=0; i<8; i=i+1) begin
                uart_rx <= data[i];
                #(BIT_PERIOD);
            end
            uart_rx <= 1; #(BIT_PERIOD); // stop bit
            $display("[%0t] TB: UART sent 0x%0h", $time, data);
        end
    endtask

    // =========================
    // Main stimulus
    // =========================
    initial begin
        // default signals
        clk = 0;
        rst_n = 0;
        push_btn = 0;
        ctrl_data = 8'h00;
        uart_rx = 1;
        spi_sclk_in = 0;
        spi_mosi_in = 0;
        spi_csn_in  = 1;

        #200;
        rst_n = 1;
        $display("[%0t] TB: Reset done", $time);

        // -----------------------------
        // Controller modes (1,2,3)
        // -----------------------------
        ctrl_data = 8'hA5; push_btn = 1; #10 push_btn = 0; #200_000; // UART
        ctrl_data = 8'h3C; push_btn = 1; #10 push_btn = 0; #200_000; // SPI
        ctrl_data = 8'h55; push_btn = 1; #10 push_btn = 0; #200_000; // I2C
        ctrl_data = 8'h00;
        // -----------------------------
        // Bridge modes (4,5,6,7)
        // -----------------------------
        push_btn = 1; #10 push_btn = 0; #(10*BIT_PERIOD); uart_send_byte(8'hA5); #200_000; // UART->SPI
        push_btn = 1; #10 push_btn = 0; #(10*BIT_PERIOD); uart_send_byte(8'h55); #200_000; // UART->I2C
        push_btn = 1; #10 push_btn = 0; spi_send_byte(8'hA5); #200_000; // SPI->UART
        push_btn = 1; #10 push_btn = 0; spi_send_byte(8'h55); #500_000; // SPI->I2C

        $display("[%0t] TB: TEST COMPLETE", $time);
        $finish;
    end

endmodule
