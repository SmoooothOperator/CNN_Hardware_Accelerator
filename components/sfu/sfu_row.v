
module sfu_row (clk, reset, acc, relu, in_a, out);

    parameter psum_bw = 16;
    parameter col = 8;

    input clk;
    input reset;
    input acc;  
    input relu; 
    input [psum_bw*col-1:0] in_a;
    output [psum_bw*col-1:0] out;

    genvar i;
    generate
        for (i = 0; i < col; i = i + 1) begin : col_num
            sfu #(.psum_bw(psum_bw)) sfu_instance (
                .clk(clk),
                .reset(reset),
                .acc(acc),   
                .relu(relu), 
                .in_a(in_a[psum_bw*(i+1)-1:psum_bw*i]),
                .out(out[psum_bw*(i+1)-1:psum_bw*i])
            );
        end
    endgenerate
endmodule