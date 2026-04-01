module corelet (clk, reset, inst, xmem_data, pmem_data_in, pmem_data_out, sfp_out, ofifo_valid);
    parameter row = 8;
    parameter col = 8;
    parameter bw = 4;
    parameter psum_bw = 16;

    input clk;
    input reset;
    input [38:0]inst; //signal BUS
    input [row*bw-1:0] xmem_data;
    input [psum_bw*col-1:0] pmem_data_in;
    

    output [psum_bw*col-1:0] pmem_data_out;
    output [col*16-1:0] sfp_out;
    output ofifo_valid;

    /////// L0 Signals ///////
        // L0 Read/Write signals
        wire l0_rd = inst[3];
        wire l0_wr = inst[2];

        // L0 Data Out
        wire [row*bw-1:0] l0_out;

        // L0 full and ready 
        wire l0_o_ready;
        wire l0_o_full;
    //////////////////////////

    /////// IFIFO Signals ///////
        // L0 Read/Write signals
        wire ififo_rd = inst[4];
        wire ififo_wr = inst[5];

        // L0 Data Out
        wire [col*bw-1:0] ififo_out;

        // L0 full and ready 
        wire ififo_o_ready;
        wire ififo_o_full;
    //////////////////////////

    /////// Mac Array Signals ///////
        // Instrustion signals
        wire load = inst[0];
        wire execute = inst[1];

        // Mac Array Outputs
        wire [psum_bw*col-1:0] mac_out;

        // This signals OFIFOs to write
        wire [col-1:0] valid;

        // Mode select output stationary
        wire mode_sel = inst[35];

        // Mode select SIMD
        wire two_bit_mode = inst[37];

        // Output stationary ready to output
        wire os_out = inst[36];

        // SIMD load b2 
        wire load_b2 = inst[38];

    //////////////////////////

    /////// OFIFO Signals ///////
        // OFIFO read signal
        wire ofifo_rd = inst[6];

        // OFIFO full and ready 
        wire ofifo_o_ready;
        wire ofifo_o_full;
    //////////////////////////

    /////// SFU Signals ///////
        // Acc & relu
        wire acc = inst[33];
        wire relu = inst[34];

    //////////////////////////

    
    // Component instances here...
    // ---------------------------------------------------------------------------------
    // L0 instance (the FIFO on the left side of systolic array)
    l0 #(.bw(bw), .row(row)) l0_instance (
        .clk(clk),
        .reset(reset),
        .wr(l0_wr),
        .rd(l0_rd),
        .in(xmem_data),
            .out(l0_out),
            .o_full(l0_o_full),
            .o_ready(l0_o_ready)
    );

    // IFIFO instance (the FIFO on the north side of the array, used for weight stationary mapping)
    ififo #(.bw(bw), .col(col)) ififo_instance (
        .clk(clk),
        .reset(reset),
        .wr(ififo_wr),
        .rd(ififo_rd),
        .in(xmem_data),
            .out(ififo_out),
            .o_full(ififo_o_full),
            .o_ready(ififo_o_ready)
    );

    // MAC Array instance
    mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_instance (
        .clk(clk),
        .reset(reset),
        .in_w(l0_out), // output of L0 FIFO
        .in_n(ififo_out), //nothing at north for weight stationary right now..
        .inst_w({execute, load}),
        .mode_sel(mode_sel),
        .os_out(os_out),
        .two_bit_mode(two_bit_mode),
        .load_b2(load_b2),
            .out_s(mac_out),
            .valid(valid)
            
    );
    
    // OFIFO instance
    ofifo #(.bw(bw), .psum_bw(psum_bw), .col(col)) ofifo_instance(
        .clk(clk),
        .reset(reset),
        .wr(valid), // comes from last row of mac array
        .rd(ofifo_rd),
        .in(mac_out),
            .out(pmem_data_out),
            .o_full(ofifo_o_full),
            .o_ready(ofifo_o_ready),
            .o_valid(ofifo_valid) // send to core.v and then SRAM
    );

    // SFU instance
    sfu_row #(.psum_bw(psum_bw), .col(col)) sfu_row_instance (
        .clk(clk),
        .reset(reset),
        .acc(acc),
        .relu(relu),
        .in_a(pmem_data_in),
            .out(sfp_out)
    );

    // ---------------------------------------------------------------------------------


endmodule