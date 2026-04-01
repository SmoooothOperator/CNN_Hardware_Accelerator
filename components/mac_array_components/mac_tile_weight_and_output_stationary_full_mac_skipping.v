module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, two_bit_mode, load_b2, mode_sel, os_out, reset);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
input two_bit_mode; // this will be an input later. 0 = 4bit mode, 1 = 2bit mode
input load_b2;
input  mode_sel; // 0 for weight stationary, 1 for output stationary
input  os_out; // This is for sending out the accumulated value for output stationary

reg    [bw-1:0] a_q; //act
reg    [1:0] alo_q; // lower 2 bits of activation
reg    [1:0] ahi_q; // upper 2 bits of activation
reg    [bw-1:0] b_q; //weight
reg    [bw-1:0] b2_q; //weight for other 2bit mac
reg    [psum_bw-1:0] c_q;
reg    [psum_bw-1:0] c_q2; // this is strictly used for 2 bit mode output stationary

reg    [bw-1:0] b_q_mac; //weight
reg    [bw-1:0] b2_q_mac; //weight for other 2bit mac
reg    [psum_bw-1:0] c_q_mac;
reg    [psum_bw-1:0] c_q2_mac; // this is strictly used for 2 bit mode output stationary

reg    [1:0] inst_q;
reg    [1:0] load_ready_q;


wire g_clk;

//Whether the weight or activation is zero
wire input_zero;
wire weight_zero;

wire    two_bit_mode;
wire    [psum_bw-1:0] out_s_lo;
wire    [psum_bw-1:0] out_s_hi;
wire    [psum_bw-1:0] out_s_2bitmode;
wire    [psum_bw-1:0] out_s_4bitmode; // this is equal to mac_out wire in output stationary version
//wire    [psum_bw-1:0] out_s_true;
//wire    different;

// may or may not need
// wire [psum_bw-1:0] mac_out; // Output stationary mac_out goes to c_q

assign input_zero = (a_q == 0) | (b_q == 0 & b2_q == 0);
assign weight_zero = (b_q == 0) & (b2_q == 0);


//assign different = (out_s_4bitmode != out_s_true);
assign out_s_4bitmode = out_s_lo + (out_s_hi<<2);
assign out_s_2bitmode = out_s_lo + out_s_hi;

// If os_out, meaning output stationary is done computing, we pass the values out (c_q)
// if not os_out, then we see if output stationary is selected (mode_sel), if so, we pass weights south
// if weight stationary, (~mode_sel), then pass the psum according to SIMD enabled or not
assign out_s = os_out ? (two_bit_mode ? c_q2_mac : c_q_mac) : (mode_sel ? (b_q) : (input_zero ? (c_q) : (two_bit_mode ? (out_s_2bitmode) : (out_s_4bitmode))));
assign out_e = a_q; // Pass the input east
assign inst_e = inst_q; // Pass instruction east

//assign two_bit_mode = 1'b0; // fixed at 4 bit to test if 2bit mac works

assign g_clk = clk & (!weight_zero & in_w != 0) & ~mode_sel; // gating the clock when both weight and input are zero
assign g_os_clk = clk & ((in_n != 0) & (in_w != 0)) & mode_sel; // gating the clock when both input weight and input activation are zero for output stationary


always@ (posedge g_clk) begin
        // // if both inputs are non zero, update the values

        c_q_mac <= in_n;

        if ((inst_w[0] | inst_w[1]) ) begin
                alo_q <= in_w[1:0];
                ahi_q <= in_w[3:2];
        end


end

always@ (posedge g_os_clk) begin

        if ((inst_w[0] | inst_w[1])) begin
                alo_q <= in_w[1:0];
                ahi_q <= in_w[3:2];
                b_q_mac <= in_n;
                b2_q_mac <= in_n;
        end
end

always@ (posedge clk) begin
        if (reset == 1) begin
                inst_q <= 0;
                load_ready_q <= 2'b11; // ready to load both b and b2 at the beginning
                c_q <= 0;
                c_q2 <= 0;
                c_q_mac <= 0;
                c_q2_mac <= 0;
                a_q <= 0; // if these are not zeroed we risk x state

                alo_q <= 0;
                ahi_q <= 0;

                b_q <= 0;
                b2_q <= 0;
                b_q_mac <= 0;
                b2_q_mac <= 0;

        end
        else begin
                inst_q[1] <= inst_w[1];
                // If weight stationary
                if(~mode_sel)begin // if os out is high it means output stationary calculation is done, ready to pass out data
                        // Always recieve psum from north 
                        c_q <= in_n;

                end

                if(os_out) begin
                        c_q_mac <= in_n;
                        if(mode_sel & two_bit_mode)begin
                                c_q2_mac <= c_q_mac;
                        end
                end

                // Load new input either when kernel loading or executing, 
                // becuase we would be ready to execute next cycles if either of these happens
                if (inst_w[0] | inst_w[1]) begin
                        a_q <= in_w;
                        // alo_q <= in_w[1:0];
                        // ahi_q <= in_w[3:2];

                        if (mode_sel) begin
                                // alo_q <= in_w[1:0];
                                // ahi_q <= in_w[3:2];
                                // Get weight from the north when 
                                // inst_w[1] is 1, otherwise w from north 
                                // might be x, and lead to errors
                                b_q <= in_n;
                                b2_q <= in_n;
                                // b_q_mac <= in_n;
                                // b2_q_mac <= in_n;

                                if (!input_zero) begin
                                        if (two_bit_mode) begin
                                        // add mac output to the c_q accumulator
                                                c_q_mac <= out_s_lo;
                                                c_q2_mac <= out_s_hi;
                                        end
                                        else begin
                                                c_q_mac <= out_s_4bitmode;
                                        end
                                end
                        end
                end

                // Delay closing c_q for one cycle so final accumulation can be done
                if (inst_w[0] | inst_w[1] | inst_q[1]) begin
                        // If output stationary
                        if (!input_zero) begin
                                if (mode_sel) begin
                                        if (two_bit_mode) begin
                                        // add mac output to the c_q accumulator
                                                c_q_mac <= out_s_lo;
                                                c_q2_mac <= out_s_hi;
                                        end
                                        else begin
                                                c_q_mac <= out_s_4bitmode;
                                        end

                                end
                        end
                end
                // Hold the accumulated value in a safe state between ic cycles (time k)
                if (~inst_w[1] & inst_q[1] & mode_sel) begin
                        a_q <= 0;
                        alo_q <= 0;
                        ahi_q <= 0;
                        b_q <= 0;
                        b2_q <= 0;
                        b_q_mac <= 0;
                        b2_q_mac <= 0;
                end

                //////////////////////////////////////////////////////////////////////////////////////////////////////
                //////// WEIGHT STATIONARY LOGIC //////////////////////
                ///////////////////////////////////////////////////////
                // load_ready_q is only reset when we load new kij
                if (inst_w[0] && load_ready_q && ~mode_sel) begin
                        if (two_bit_mode) begin
                                if (load_b2 && load_ready_q[1]) begin
                                        b2_q <= in_w;
                                        b2_q_mac <= in_w;
                                        load_ready_q[1] <= 0;
                                end
                                else if (!load_b2 && load_ready_q[0]) begin
                                        b_q <= in_w;
                                        b_q_mac <= in_w;
                                        load_ready_q[0] <= 0;
                                end
                        end else begin
                                b_q <= in_w;
                                b2_q <= in_w;
                                b_q_mac <= in_w;
                                b2_q_mac <= in_w;
                                load_ready_q <= 0;
                        end
                end
                // This creates the perfect delay for passing from the west (l0)
                // it would wait one cycle before passing on inst_w[0], so the data can arrive in time
                if (load_ready_q != 2'b11) begin
                        if (two_bit_mode) begin
                                if (load_b2 & !load_ready_q[1]) begin
                                        inst_q[0] <= inst_w[0];
                                end
                                else if (!load_b2 & !load_ready_q[0]) begin
                                        inst_q[0] <= inst_w[0];
                                end

                        end
                        else begin
                                inst_q[0] <= inst_w[0];
                        end
                end
                ///////////////////////////////////////////////////////
                //////// WEIGHT STATIONARY LOGIC //////////////////////
                /////////////////////////////////////////////////////////////////////////////////////////////////////
        end

end

mac2 #(.bw(bw), .psum_bw(psum_bw)) mac2_instance_lo (
        .a(alo_q),
        .b(b_q_mac),
        .c(c_q_mac),
        .out(out_s_lo)
);

mac2 #(.bw(bw), .psum_bw(psum_bw)) mac2_instance_hi (
        .a(ahi_q),
        .b(b2_q_mac),
        .c(c_q2_mac), // changed this to c_q2 for output stationary. c_q2 should be 16'b0 anyways when output stationary not activated
        .out(out_s_hi)
);



endmodule
