
module sfu (clk, reset, acc, relu, in_a, out);

    parameter psum_bw = 16;

    input clk;
    input reset;
    input acc;  // 1: Accumulate (out + in), 0: Load/Pass-through (in)
    input relu; // 1: Enable ReLU, 0: Disable
    input [psum_bw-1:0] in_a;
    output [psum_bw-1:0] out;

    reg [psum_bw-1:0] psum_q;

    // Accumulation / Load Logic
    always @(posedge clk) begin
        if (reset) begin
            psum_q <= 0;
        end
        else if (acc) begin
            psum_q <= psum_q + in_a; // Accumulate
        end
        else begin
            psum_q <= in_a;          // Load new value (start new sum)
        end
    end

    // ReLU Logic (Combinational)
    // If ReLU is enabled and the number is negative (MSB is 1), output 0.
    // Otherwise, output the accumulated value.

    // Design choice: having the relu signals enables the calculation of layers that don't have ReLU
    assign out = (relu && psum_q[psum_bw-1]) ? {psum_bw{1'b0}} : psum_q;

endmodule