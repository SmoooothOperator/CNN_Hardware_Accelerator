module core (clk, reset, inst, D_xmem, sfp_out, ofifo_valid);
    parameter row = 8;
    parameter col = 8;
    parameter bw = 4;
    parameter psum_bw = 16;

    input clk;
    input reset;
    input [38:0] inst; // 4 more bits for SMID and output stationary
    input [bw*row-1:0] D_xmem;

    output [col*16-1:0] sfp_out;
    output ofifo_valid;


    /////// SRAM Signals ///////
        // SRAM control logics (Activation Mem (X))
        wire cen_xmem = inst[19];
        wire wen_xmem = inst[18];
        wire [10:0] a_xmem = inst[17:7];

        // XSRAM data outputs
        wire [bw*row-1:0] q_xmem;
        
        // SRAM control logics (Psum Mem (p))
        wire cen_pmem = inst[32];
        wire wen_pmem = inst[31];
        wire [10:0] a_pmem = inst[30:20];

        // Psum SRAMs data input
        wire [psum_bw*col-1:0] d_pmem;

        // Psum SRAMs data outputs
        wire [psum_bw*col-1:0] q_pmem;
    ///////////////////////////

    // Component instances here...
    // ---------------------------------------------------------------------------------
    // Instantiate SRAMs 
    // (X-Memory)
    sram_32b_w2048 xmem_inst ( //SRAM for activations
        .CLK(clk),
        .CEN(cen_xmem),
        .WEN(wen_xmem),
        .A(a_xmem),
        .D(D_xmem),   // Data comes from core input (from TB)
            .Q(q_xmem)    // Output goes to corelet
    );
    // (P-Memory) Might need a couple more 
    genvar i;
    for (i = 0; i < 4; i=i+1) begin : pmem_row // Need 4 because ofifo is 16*8 bits, 1 sram is 32 bits
        sram_32b_w2048 pmem_instance ( //SRAM for activations
            .CLK(clk),
            .CEN(cen_pmem),
            .WEN(wen_pmem),
            .A(a_pmem),
            .D(d_pmem[2*psum_bw*(i+1)-1:2*psum_bw*i]),  
                .Q(q_pmem[2*psum_bw*(i+1)-1:2*psum_bw*i])    
        );
    end


    // Instantiate corelet (**Not finalized**)
    corelet #(.bw(bw), .col(col), .row(row), .psum_bw(psum_bw)) corelet_instance (
        .clk(clk),
        .reset(reset),
        .inst(inst),        // Pass full inst or specific bits as needed
        .xmem_data(q_xmem), // Corelet reads from X-SRAM
        .pmem_data_in(q_pmem),
            .pmem_data_out(d_pmem), // Output from corlet's ofifo
            .ofifo_valid(ofifo_valid),
            .sfp_out(sfp_out)
    );
    // ---------------------------------------------------------------------------------


endmodule
