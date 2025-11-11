module ro16_top(
    output [15:0] ro_out
);
    // Assign different delays to each RO for different frequencies
    ring_osc #(3)   RO1 (.clk_out(ro_out[0]));
    ring_osc #(5)   RO2 (.clk_out(ro_out[1]));
    ring_osc #(7)   RO3 (.clk_out(ro_out[2]));
    ring_osc #(9)   RO4 (.clk_out(ro_out[3]));
    ring_osc #(4)   RO5 (.clk_out(ro_out[4]));
    ring_osc #(6)   RO6 (.clk_out(ro_out[5]));
    ring_osc #(8)   RO7 (.clk_out(ro_out[6]));
    ring_osc #(10)  RO8 (.clk_out(ro_out[7]));
    ring_osc #(2)   RO9 (.clk_out(ro_out[8]));
    ring_osc #(3)   RO10(.clk_out(ro_out[9]));
    ring_osc #(5)   RO11(.clk_out(ro_out[10]));
    ring_osc #(7)   RO12(.clk_out(ro_out[11]));
    ring_osc #(9)   RO13(.clk_out(ro_out[12]));
    ring_osc #(11)  RO14(.clk_out(ro_out[13]));
    ring_osc #(13)  RO15(.clk_out(ro_out[14]));
    ring_osc #(15)  RO16(.clk_out(ro_out[15]));
endmodule