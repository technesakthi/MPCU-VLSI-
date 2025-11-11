module puf_top_8bit (
    input clk,          // system clock
    input rst,          // reset
    output reg [7:0] secure_id  // 8-bit Secure ID output
);

    wire [15:0] ro_out;      // Outputs from 16 ROs
    wire [2:0] sel;          // Random select line from TRNG
    wire mux1_out, mux2_out; // Selected outputs from 2 MUXes
    wire secure_bit;         // Comparison output bit
    reg [3:0] bit_count;     // Counter for 8-bit collection

    // --- Instantiate 16 Ring Oscillators ---
    ro16_top ROs (
        .ro_out(ro_out)
    );

    // --- Instantiate TRNG (generates 3-bit random select) ---
    trng_3bit TRNG (
    .clk(clk),
    .rst(rst),
    .random_out(sel)   // connect TRNG output to MUX select line
);

    // --- Instantiate MUX pair ---
    RO_MUX MUX_PAIR (
        .ro_out(ro_out),
        .sel(sel),
        .mux1_out(mux1_out),
        .mux2_out(mux2_out)
    );

    // --- Comparator / Secure Bit Generator ---
    assign secure_bit = mux1_out ^ mux2_out;

    // --- 8-bit Secure ID generation logic ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            secure_id <= 8'b0;
            bit_count <= 0;
        end 
        else begin
            if (bit_count < 8) begin
                secure_id[bit_count] <= secure_bit;
                bit_count <= bit_count + 1;
            end
        end
    end

endmodule
