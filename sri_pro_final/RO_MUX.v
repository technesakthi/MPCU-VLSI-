`timescale 1ns/1ps

module RO_MUX(
    input [15:0] ro_out,      // 16 RO outputs
    input [2:0] sel,          // 3-bit select line
    output reg mux1_out,      // Output of MUX1 (odd ROs)
    output reg mux2_out       // Output of MUX2 (even ROs)
);

    always @(*) begin
        case(sel)
            3'b000: begin mux1_out = ro_out[1];  mux2_out = ro_out[0];  end
            3'b001: begin mux1_out = ro_out[3];  mux2_out = ro_out[2];  end
            3'b010: begin mux1_out = ro_out[5];  mux2_out = ro_out[4];  end
            3'b011: begin mux1_out = ro_out[7];  mux2_out = ro_out[6];  end
            3'b100: begin mux1_out = ro_out[9];  mux2_out = ro_out[8];  end
            3'b101: begin mux1_out = ro_out[11]; mux2_out = ro_out[10]; end
            3'b110: begin mux1_out = ro_out[13]; mux2_out = ro_out[12]; end
            3'b111: begin mux1_out = ro_out[15]; mux2_out = ro_out[14]; end
            default: begin mux1_out = 1'b0; mux2_out = 1'b0; end
        endcase
    end
endmodule
