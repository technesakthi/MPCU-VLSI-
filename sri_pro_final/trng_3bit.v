module trng_3bit (
    input clk,
    input rst,
    output reg [2:0] random_out
);
    reg [2:0] lfsr;
    reg [3:0] cycle_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lfsr <= 3'b101;        // Seed value
            cycle_count <= 0;
            random_out <= 3'b000;
        end else begin
            cycle_count <= cycle_count + 1;
            
            // Update every 10 clock cycles
            if (cycle_count == 4'd10) begin
                lfsr <= {lfsr[1:0], lfsr[2] ^ lfsr[1] ^ lfsr[0]};
                random_out <= lfsr ^ $random;  // Add randomness
                cycle_count <= 0;
            end
        end
    end
endmodule
