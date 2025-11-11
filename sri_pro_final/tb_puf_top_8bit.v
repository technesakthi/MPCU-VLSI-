`timescale 1ns/1ps

module tb_puf_top_8bit_v2;

    reg clk, rst;
    wire [7:0] secure_id;

    // If your PUF has enable, uncomment this
    // reg enable;

    // Instantiate DUT
    puf_top_8bit DUT (
        .clk(clk),
        .rst(rst),
        .secure_id(secure_id)
        // .enable(enable)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset and simulation control
    initial begin
        $dumpfile("puf_top_8bit_v2.vcd");
        $dumpvars(0, tb_puf_top_8bit_v2);

        rst = 1;
        // enable = 0;   // if needed
        #20;
        rst = 0;
        // enable = 1;   // if needed

        // Wait long enough for PUF to stabilize
        repeat (500) @(posedge clk);

        // Print secure ID periodically
        $display("Secure ID at time %0t: %b", $time, secure_id);

        repeat (500) @(posedge clk);
        $display("Final 8-bit Secure ID = %b", secure_id);

        $finish;
    end

endmodule
