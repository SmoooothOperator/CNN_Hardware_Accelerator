 
`timescale 1ns/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9;
parameter len_onij = 16;
parameter col = 8;
parameter row = 8;
parameter len_nij = 36;

reg clk = 0;
reg reset = 1;

// This whole line of 34 signals gets sent as a BUS
wire [38:0] inst_q; // added one more bit for relu signal

reg [1:0]  inst_w_q = 0; // This feels unused and not needed, due to load and execute signals on the bus 
reg [bw*row-1:0] D_xmem_q = 0;
reg CEN_xmem = 1;
reg WEN_xmem = 1;
reg [10:0] A_xmem = 0;
reg CEN_xmem_q = 1;
reg WEN_xmem_q = 1;
reg [10:0] A_xmem_q = 0;
reg CEN_pmem = 1;
reg WEN_pmem = 1;
reg [10:0] A_pmem = 0;
reg CEN_pmem_q = 1;
reg WEN_pmem_q = 1;
reg [10:0] A_pmem_q = 0;
reg ofifo_rd_q = 0;
reg ififo_wr_q = 0;
reg ififo_rd_q = 0;
reg l0_rd_q = 0;
reg l0_wr_q = 0;
reg execute_q = 0;
reg load_q = 0;
reg acc_q = 0;
reg acc = 0;
reg relu = 0;
reg relu_q =0;
reg mode_sel = 0;
reg mode_sel_q = 0;
reg os_out = 0;
reg os_out_q = 0;
reg two_bit_mode = 0;
reg two_bit_mode_q = 0;
reg load_b2 = 0;
reg load_b2_q = 0;

reg [1:0]  inst_w; 
reg [bw*row-1:0] D_xmem;
reg [63:0] weight_mem;
wire [31:0] weight_mem_1;
wire [31:0] weight_mem_2;

assign weight_mem_1 = {
weight_mem[63:60],
weight_mem[55:52],
weight_mem[47:44],
weight_mem[39:36],
weight_mem[31:28],
weight_mem[23:20],
weight_mem[15:12],
weight_mem[7:4]
};

assign weight_mem_2 = {
weight_mem[59:56],
weight_mem[51:48],
weight_mem[43:40],
weight_mem[35:32],
weight_mem[27:24],
weight_mem[19:16],
weight_mem[11:8],
weight_mem[3:0]
};



reg [psum_bw*col-1:0] answer;


reg ofifo_rd;
reg ififo_wr;
reg ififo_rd;
reg l0_rd;
reg l0_wr;
reg execute;
reg load;
reg [8*30:1] stringvar;
reg [8*64:1] w_file_name;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, kij;
integer error;

// Assignments for the inst_q bus
assign inst_q[38] = load_b2_q;
assign inst_q[37] = two_bit_mode_q;
assign inst_q[36] = os_out_q;
assign inst_q[35] = mode_sel_q;
assign inst_q[34] = relu_q;
assign inst_q[33] = acc_q;
assign inst_q[32] = CEN_pmem_q; // psum sram chip enable (0 for enable, 1 for disable)
assign inst_q[31] = WEN_pmem_q; // psum sram write enable (0 for enable)
assign inst_q[30:20] = A_pmem_q; // psum sram address
assign inst_q[19]   = CEN_xmem_q; // activation sram
assign inst_q[18]   = WEN_xmem_q; 
assign inst_q[17:7] = A_xmem_q;
assign inst_q[6]   = ofifo_rd_q;
assign inst_q[5]   = ififo_wr_q;
assign inst_q[4]   = ififo_rd_q;
assign inst_q[3]   = l0_rd_q;
assign inst_q[2]   = l0_wr_q;
assign inst_q[1]   = execute_q; 
assign inst_q[0]   = load_q; 

// These regs are for testing/verification only
  reg [31:0] bank0_word;
  reg [31:0] bank1_word;
  reg [31:0] bank2_word;
  reg [31:0] bank3_word;
  reg signed [15:0] bank0_lower;
  reg signed [15:0] bank0_upper;
  reg signed [15:0] bank1_lower;
  reg signed [15:0] bank1_upper;
  reg signed [15:0] bank2_lower;
  reg signed [15:0] bank2_upper;
  reg signed [15:0] bank3_lower;
  reg signed [15:0] bank3_upper;
  integer ind;



// Core instance
core  #(.bw(bw), .col(col), .row(row), .psum_bw(psum_bw)) core_instance (
	.clk(clk), 
	.inst(inst_q),
	.ofifo_valid(ofifo_valid),
        .D_xmem(D_xmem_q), // this is memory data input
        .sfp_out(sfp_out), 
	.reset(reset)); 


initial begin 

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1;
  WEN_xmem = 1;
  A_xmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;
  two_bit_mode = 0;
  load_b2 = 0;
  mode_sel = 0;
  os_out = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  x_file = $fopen("text_files/2bit/activation.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   
  /////////////////////////

  /////// Activation data writing to memory ///////
  for (t=0; t<len_nij; t=t+1) begin  
    #0.5 clk = 1'b0;  
    x_scan_file = $fscanf(x_file,"%32b", D_xmem); 
    WEN_xmem = 0; 
    CEN_xmem = 0; 
    if (t>0) A_xmem = A_xmem + 1;
    #0.5 clk = 1'b1;   
  end

  #0.5 clk = 1'b0;  
  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1; 

  $fclose(x_file);
  /////////////////////////////////////////////////
  // -----------------------------------------------------------------------

  // VISUAL VERIFICATION OF XMEM CONTENTS
  // -----------------------------------------------------------------------
  // Need one more clk cycle for the last write to show up vitually on SRAM 
  // #0.5 clk = 1'b0;   
  // #0.5 clk = 1'b1;   
  // $display("// -----------------------------------------------------------------------");
  //   $display("// VISUAL VERIFICATION OF Act Loading to XMEM CONTENTS");
  //   $display("// -----------------------------------------------------------------------");
  // $display("\nActivation data loaded into XMEM (Addresses 0 to %0d):", len_nij-1);
  // $display("Addr | Binary                           | Hex");
  // $display("-----|----------------------------------|---------");
  
  // for (i = 0; i < len_nij; i = i + 1) begin
  //     // NOTE: 'mem' must match the variable name of the reg array inside sram_32b_w2048.v
  //     // If it is named 'memory' or 'ram', change .mem[i] to .memory[i]
  //     $display("%4d | %b | %h \n", i, core_instance.xmem_inst.memory[i], core_instance.xmem_inst.memory[i]);
  // end
  // $display("----------------------------------------------------------\n");


  /////// Kernel weight writing to memory ///////
  for (kij=0; kij<9; kij=kij+1) begin  // kij loop

    // Note: added to the path to suit my directory structure, might need to change back for grading
    case(kij)
     0: w_file_name = "text_files/2bit/weight_itile0_otile0_kij0.txt";
     1: w_file_name = "text_files/2bit/weight_itile0_otile0_kij1.txt";
     2: w_file_name = "text_files/2bit/weight_itile0_otile0_kij2.txt";
     3: w_file_name = "text_files/2bit/weight_itile0_otile0_kij3.txt";
     4: w_file_name = "text_files/2bit/weight_itile0_otile0_kij4.txt";
     5: w_file_name = "text_files/2bit/weight_itile0_otile0_kij5.txt";
     6: w_file_name = "text_files/2bit/weight_itile0_otile0_kij6.txt";
     7: w_file_name = "text_files/2bit/weight_itile0_otile0_kij7.txt";
     8: w_file_name = "text_files/2bit/weight_itile0_otile0_kij8.txt";
    endcase
   
    $display("%s", w_file_name);

    w_file = $fopen(w_file_name, "r");
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);


    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1; 

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   



    /////// Kernel data writing to memory ///////

    // Using the same SRAM for weight and act
    A_xmem = 11'b10000000000; // Starts at a higher address (1024) so activation has enough space

    for (t=0; t<col*2; t=t+1) begin  // 2 BIT: 16 input channels * 4 bits = 64 bits. Need 2 rows of 32bit SRAM to store 64 bits. Also there are 16 output channels. 16*2 = 32 = 8*4
      if (t%2 == 0) begin
        w_scan_file = $fscanf(w_file,"%64b", weight_mem);
      end 
      #0.5 clk = 1'b0;  
      if (t%2==0) begin
        D_xmem = weight_mem_2;
      end
      else begin
        D_xmem = weight_mem_1;
      end
      WEN_xmem = 0; 
      CEN_xmem = 0; 
      if (t>0) A_xmem = A_xmem + 8*(t%2);
      if (t>0 && (t%2==0)) A_xmem = A_xmem - 8 + 1; 
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1; 
    $fclose(w_file);
    /////////////////////////////////////
    // VISUAL VERIFICATION OF XMEM CONTENTS (Only Kij = 1)
    //-----------------------------------------------------------------------
    //Need one more clk cycle for the last write to show up vitually on SRAM 
    // #0.5 clk = 1'b0;   
    // #0.5 clk = 1'b1;   
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF Kernel Loading to XMEM CONTENTS");
    // $display("// -----------------------------------------------------------------------");
    // $display("\nKernel weights (kij) loaded into XMEM (Addresses 1024 to %0d):", 1024+col*2-1);
    // $display("Addr | Binary                           | Hex");
    // $display("-----|----------------------------------|---------");
    
    // for (i = 1024; i < (col*4 + 1024); i = i + 1) begin
    //     // NOTE: 'mem' must match the variable name of the reg array inside sram_32b_w2048.v
    //     // If it is named 'memory' or 'ram', change .mem[i] to .memory[i]
    //     $display("%4d | %b | %h \n", i, core_instance.xmem_inst.memory[i], core_instance.xmem_inst.memory[i]);
    // end
    // $display("----------------------------------------------------------\n");
    //$finish;
    
    /////// Kernel data writing to L0 ///////
    // Need to send to memory 1 cycle earlier as it has 1 cycle higher wait
    #0.5 clk = 1'b0;   
    A_xmem = 1024; // Read from proper address, kij at 1024 to 1031
    WEN_xmem = 1;  
    CEN_xmem = 0;
    #0.5 clk = 1'b1;  

    for (t=0; t<col*2; t=t+1)begin // 2 BIT: 16 output channels * 4 bits = 64 bits. Need 2 rows of 32bit SRAM to store 64 bits. Total is 32 rows, but only 16 are written for now since there's only 16 weight registers in a row
      //Prepare SRAM to be read
      #0.5 clk = 1'b0;  
      WEN_xmem = 1;  
      CEN_xmem = 0;
      // Enable L0 write
      l0_wr = 1; 
      l0_rd = 0;

      A_xmem = A_xmem + 1; 
      #0.5 clk = 1'b1; 

    end
    
    #0.5 clk = 1'b0; WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    l0_wr = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////

    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    // -----------------------------------------------------------------------
    // VISUAL VERIFICATION OF L0 FIFO CONTENTS
    // -----------------------------------------------------------------------
  //   $display("// -----------------------------------------------------------------------");
  //   $display("// VISUAL VERIFICATION OF L0 FIFO CONTENTS");
  //   $display("// -----------------------------------------------------------------------");
  //   $display("\nL0 FIFO Contents (First %0d words per row):", col);
  //   $display("Row | Depth | Value (Hex)");
  //   $display("----|-------|-------------");

  //   `define PRINT_L0_ROW(ROW_IDX) \
  //       $display(" %2d |   0  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q0); \
  //       $display(" %2d |   1  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q1); \
  //       $display(" %2d |   2  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q2); \
  //       $display(" %2d |   3  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q3); \
  //       $display(" %2d |   4  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q4); \
  //       $display(" %2d |   5  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q5); \
  //       $display(" %2d |   6  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q6); \
  //       $display(" %2d |   7  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q7); \
	// $display(" %2d |   8  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q8); \
  //       $display(" %2d |   9  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q9); \
  //       $display(" %2d |   10  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q10); \
  //       $display(" %2d |   11  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q11); \
  //       $display(" %2d |   12  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q12); \
  //       $display(" %2d |   13  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q13); \
  //       $display(" %2d |   14  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q14); \
  //       $display(" %2d |   15  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q15); \
  //       $display("----|-------|-------------");\
  //       $display(" Write_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.wr_ptr); \
  //       $display(" Read_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.rd_ptr); \
  //       $display("----|-------|-------------");\

  //   //Manually call the macro for each row
  //   `PRINT_L0_ROW(0)
  //   `PRINT_L0_ROW(1)
  //   `PRINT_L0_ROW(2)
  //   `PRINT_L0_ROW(3)
  //   `PRINT_L0_ROW(4)
  //   `PRINT_L0_ROW(5)
  //   `PRINT_L0_ROW(6)
  //   `PRINT_L0_ROW(7)

  //   `undef PRINT_L0_ROW // Clean up
  //   $display("----------------------------------------------------------\n");
    // -----------------------------------------------------------------------
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    //$finish;
    /////// Kernel loading to PEs ///////
    
    // Helper Macros for Visualization
    // Adjust 'mac_array_instance', 'col_num', 'w_q', 'a_q' if your names differ
    `define TILE(R, C) core_instance.corelet_instance.mac_array_instance.row_num[R].mac_row_instance.col_num[C].mac_tile_instance
    
    `define PRINT_MAC_ROW(R) \
    $display("R%0d | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h |", R, \
       `TILE(R,1).b_q, `TILE(R,1).b2_q, `TILE(R,1).a_q, \
       `TILE(R,2).b_q, `TILE(R,2).b2_q, `TILE(R,2).a_q, \
       `TILE(R,3).b_q, `TILE(R,3).b2_q, `TILE(R,3).a_q, \
       `TILE(R,4).b_q, `TILE(R,4).b2_q, `TILE(R,4).a_q, \
       `TILE(R,5).b_q, `TILE(R,5).b2_q, `TILE(R,5).a_q, \
       `TILE(R,6).b_q, `TILE(R,6).b2_q, `TILE(R,6).a_q, \
       `TILE(R,7).b_q, `TILE(R,7).b2_q, `TILE(R,7).a_q, \
       `TILE(R,8).b_q, `TILE(R,8).b2_q, `TILE(R,8).a_q);

    
    // L0 read enable logic
    for (t=0; t<col+row*2; t=t+1) begin  // col+row*2 because that is the total cycle to populate the array
      #0.5 clk = 1'b0;   load_b2 = 0; two_bit_mode = 1;
      // Only need to send inst_w once, as it gets passed
      if (t == 0)begin
        load = 1;
        execute = 0;
      end
      // After col number of cycles, first fifo in l0 would be empty
      // so we need to shut it down. The shut down signal propapages to the next
      // fifo columns in l0 automatically cycle by cycle (check l0 code)
      if (t < col)begin
        l0_rd = 1;
      end
      else begin
        l0_rd = 0;
      end
      #0.5 clk = 1'b1;  

      // --- VISUALIZATION BLOCK ---
      // $display("\nCycle %0d: MAC Array State [Weight Activation]", t);
      // $display("   | C0      | C1      | C2      | C3      | C4      | C5      | C6      | C7      |");
      // $display("---|---------|---------|---------|---------|---------|---------|---------|---------|");
      // `PRINT_MAC_ROW(1)
      // `PRINT_MAC_ROW(2)
      // `PRINT_MAC_ROW(3)
      // `PRINT_MAC_ROW(4)
      // `PRINT_MAC_ROW(5)
      // `PRINT_MAC_ROW(6)
      // `PRINT_MAC_ROW(7)
      // `PRINT_MAC_ROW(8)

      // $display("----------------------------------------------------------------------------------");
    //   // ---------------------------
    end
    // Extra cycle for the last PE to store the weight
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;
    l0_rd = 0;
    load = 0;
    execute = 0;
    #0.5 clk = 1'b1;
    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<30 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end
    /////////////////////////////////////


    for (t=0; t<col+row*2; t=t+1) begin  // col+row*2 because that is the total cycle to populate the array
      #0.5 clk = 1'b0;   load_b2 = 1; two_bit_mode = 1;
      // Only need to send inst_w once, as it gets passed
      if (t == 0)begin
        load = 1;
        execute = 0;
      end
      // After col number of cycles, first fifo in l0 would be empty
      // so we need to shut it down. The shut down signal propapages to the next
      // fifo columns in l0 automatically cycle by cycle (check l0 code)
      if (t < col)begin
        l0_rd = 1;
      end
      else begin
        l0_rd = 0;
      end
      #0.5 clk = 1'b1;  

      // --- VISUALIZATION BLOCK ---
      // $display("\nCycle %0d: MAC Array State [Weight Activation]", t);
      // $display("   | C0      | C1      | C2      | C3      | C4      | C5      | C6      | C7      |");
      // $display("---|---------|---------|---------|---------|---------|---------|---------|---------|");
      // `PRINT_MAC_ROW(1)
      // `PRINT_MAC_ROW(2)
      // `PRINT_MAC_ROW(3)
      // `PRINT_MAC_ROW(4)
      // `PRINT_MAC_ROW(5)
      // `PRINT_MAC_ROW(6)
      // `PRINT_MAC_ROW(7)
      // `PRINT_MAC_ROW(8)

      // $display("----------------------------------------------------------------------------------");
    //   // ---------------------------
    end

    // Extra cycle for the last PE to store the weight
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0; 
    l0_rd = 0;
    load = 0;
    execute = 0;
    #0.5 clk = 1'b1;
     // --- VISUALIZATION BLOCK FOR COMPLETED LOAD---
      // $display("\nAfter Loading Finished: MAC Array State [Weight Activation]");
      // $display("   | C0      | C1      | C2      | C3      | C4      | C5      | C6      | C7      |");
      // $display("---|---------|---------|---------|---------|---------|---------|---------|---------|");
      // `PRINT_MAC_ROW(1)
      // `PRINT_MAC_ROW(2)
      // `PRINT_MAC_ROW(3)
      // `PRINT_MAC_ROW(4)
      // `PRINT_MAC_ROW(5)
      // `PRINT_MAC_ROW(6)
      // `PRINT_MAC_ROW(7)
      // `PRINT_MAC_ROW(8)

      // $display("----------------------------------------------------------------------------------");
      // ---------------------------

    // Clean up macros
    `undef TILE
    `undef PRINT_MAC_ROW
    //$finish;
    /////////////////////////////////////
  
  // NOTE on previous two parts:
  // If we want to do parallel L0 writing and PE loading, 
  // we would have to port the L0 o_ready, and o_full signals to the testbench
  // This way if L0 is full, we would have the memory wait extra cycles
  // Which is not done in the current setup, 
  // Since we currently will never run out of room in L0 doing this sequentially
  // with no parallelism 


    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end
    /////////////////////////////////////



    /////// Activation data writing to L0 ///////
    // Need to send to memory 1 cycle earlier as it has 1 cycle higher wait
    #0.5 clk = 1'b0;   
    A_xmem = 0; // Read from proper address, starting from 0 for activation
    WEN_xmem = 1;  
    CEN_xmem = 0;
    #0.5 clk = 1'b1;  

    for (t=0; t<len_nij; t=t+1)begin
      //Prepare SRAM to be read
      #0.5 clk = 1'b0;  
      WEN_xmem = 1;  
      CEN_xmem = 0;
      // Enable L0 write
      l0_wr = 1; 
      l0_rd = 0;

      A_xmem = A_xmem + 1; 
      #0.5 clk = 1'b1; 

    end
    
    #0.5 clk = 1'b0; WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    l0_wr = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////

    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    // -----------------------------------------------------------------------
    // VISUAL VERIFICATION OF L0 FIFO CONTENTS
    // -----------------------------------------------------------------------
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF L0 FIFO CONTENTS (X)");
    // $display("// -----------------------------------------------------------------------");
    // $display("\nL0 FIFO Contents (First %0d words per row):", col);
    // $display("Row | Depth | Value (Hex)");
    // $display("----|-------|-------------");

    // `define PRINT_L0_ROW_64(ROW_IDX) \
    // $display(" %2d |  0  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q16); \
    // $display(" %2d |  1  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q17); \
    // $display(" %2d |  2  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q18); \
    // $display(" %2d |  3  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q19); \
    // $display(" %2d |  4  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q20); \
    // $display(" %2d |  5  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q21); \
    // $display(" %2d |  6  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q22); \
    // $display(" %2d |  7  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q23); \
    // $display(" %2d |  8  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q24); \
    // $display(" %2d |  9  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q25); \
    // $display(" %2d | 10  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q26); \
    // $display(" %2d | 11  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q27); \
    // $display(" %2d | 12  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q28); \
    // $display(" %2d | 13  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q29); \
    // $display(" %2d | 14  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q30); \
    // $display(" %2d | 15  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q31); \
    // $display(" %2d | 16  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q32); \
    // $display(" %2d | 17  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q33); \
    // $display(" %2d | 18  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q34); \
    // $display(" %2d | 19  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q35); \
    // $display(" %2d | 20  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q36); \
    // $display(" %2d | 21  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q37); \
    // $display(" %2d | 22  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q38); \
    // $display(" %2d | 23  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q39); \
    // $display(" %2d | 24  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q40); \
    // $display(" %2d | 25  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q41); \
    // $display(" %2d | 26  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q42); \
    // $display(" %2d | 27  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q43); \
    // $display(" %2d | 28  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q44); \
    // $display(" %2d | 29  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q45); \
    // $display(" %2d | 30  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q46); \
    // $display(" %2d | 31  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q47); \
    // $display(" %2d | 32  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q48); \
    // $display(" %2d | 33  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q49); \
    // $display(" %2d | 34  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q50); \
    // $display(" %2d | 35  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q51); \
    // $display("----|-------|-------------");\
    // $display(" Write_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.wr_ptr); \
    // $display(" Read_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.rd_ptr); \
    // $display("----|-------|-------------");

    // // Manually call the macro for each row
    // `PRINT_L0_ROW_64(0)
    // `PRINT_L0_ROW_64(1)
    // `PRINT_L0_ROW_64(2)
    // `PRINT_L0_ROW_64(3)
    // `PRINT_L0_ROW_64(4)
    // `PRINT_L0_ROW_64(5)
    // `PRINT_L0_ROW_64(6)
    // `PRINT_L0_ROW_64(7)

    // `undef PRINT_L0_ROW_64 // Clean up
    
    // $display("----------------------------------------------------------\n");
    //$finish;
    // -----------------------------------------------------------------------
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    /////////////////////////////////////



    // OFIFO read enable logic
    for (t=0; t<len_nij+row*2+1; t=t+1) begin  // col+row*2 because that is the total cycle to populate the array
      #0.5 clk = 1'b0;   
      // Only need to send inst_w once, as it gets passed
      
      // After nij number of cycles, first fifo in l0 would be empty
      // so we need to shut it down. The shut down signal propapages to the next
      // fifo columns in l0 automatically cycle by cycle (check l0 code)
      if (t < len_nij)begin
        l0_rd = 1; // send from l0
        load = 0;
        execute = 1;
      end
      else begin
        l0_rd = 0;
        load = 0;
        execute = 0;
      end

      // OFIFO to PMEM in parallel with execution to OFIFO
      if (t > row*2) begin
        // ofifo read enable
        ofifo_rd = 1;
        // Write signals to pmem
        WEN_pmem = 0; 
        CEN_pmem = 0; 
        if (t>row*2 + 1) A_pmem = A_pmem + 1;
      end
      else if (t == row*2) begin
        // Need this line so that the timing of memory write and ofifo read is right
        ofifo_rd = 1; 
      end

      #0.5 clk = 1'b1;  
      // Verify that OFIFO never gets full and the pointers behave properly
      // $display("// -----------------------------------------------------------------------");
      // $display("// VISUAL VERIFICATION OF OFIFO POINTERS");
      // $display("// -----------------------------------------------------------------------");
      // $display("| Write Ptr | Read Ptr");
      // $display("|-----------|----------");
      //     $display("|    %2d     |   %2d", 
      //         core_instance.corelet_instance.ofifo_instance.col_num[0].fifo_instance.wr_ptr, 
      //         core_instance.corelet_instance.ofifo_instance.col_num[0].fifo_instance.rd_ptr
      //     );
      // $display("----------------------------------------------------------\n");

    end

    #0.5 clk = 1'b0;  
    WEN_pmem = 1;  CEN_pmem = 1; ofifo_rd = 0; 
    // This makes sure we write to the next address instead of overwriting the end of this kij
    A_pmem = A_pmem + 1;

    #0.5 clk = 1'b1; 
    
    // Need two more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    // -----------------------------------------------------------------------
    // VISUAL VERIFICATION OF L0 FIFO CONTENTS
    // -----------------------------------------------------------------------
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF OFIFO CONTENTS");
    // $display("// -----------------------------------------------------------------------");
    // $display("\n OFIFO Contents (First %0d words per row):", col);
    // $display("Row | Depth | Value (Hex)");
    // $display("----|-------|-------------");

    // `define PRINT_L0_ROW_64(ROW_IDX) \
    // $display(" %2d |  0  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q0)); \
    // $display(" %2d |  1  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q1)); \
    // $display(" %2d |  2  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q2)); \
    // $display(" %2d |  3  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q3)); \
    // $display(" %2d |  4  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q4)); \
    // $display(" %2d |  5  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q5)); \
    // $display(" %2d |  6  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q6)); \
    // $display(" %2d |  7  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q7)); \
    // $display(" %2d |  8  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q8)); \
    // $display(" %2d |  9  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q9)); \
    // $display(" %2d | 10  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q10)); \
    // $display(" %2d | 11  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q11)); \
    // $display(" %2d | 12  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q12)); \
    // $display(" %2d | 13  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q13)); \
    // $display(" %2d | 14  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q14)); \
    // $display(" %2d | 15  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q15)); \
    // $display(" %2d | 16  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q16)); \
    // $display(" %2d | 17  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q17)); \
    // $display(" %2d | 18  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q18)); \
    // $display(" %2d | 19  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q19)); \
    // $display(" %2d | 20  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q20)); \
    // $display(" %2d | 21  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q21)); \
    // $display(" %2d | 22  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q22)); \
    // $display(" %2d | 23  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q23)); \
    // $display(" %2d | 24  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q24)); \
    // $display(" %2d | 25  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q25)); \
    // $display(" %2d | 26  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q26)); \
    // $display(" %2d | 27  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q27)); \
    // $display(" %2d | 28  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q28)); \
    // $display(" %2d | 29  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q29)); \
    // $display(" %2d | 30  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q30)); \
    // $display(" %2d | 31  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q31)); \
    // $display(" %2d | 32  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q32)); \
    // $display(" %2d | 33  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q33)); \
    // $display(" %2d | 34  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q34)); \
    // $display(" %2d | 35  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q35)); \

    // // Manually call the macro for each row
    // `PRINT_L0_ROW_64(0)
    // `PRINT_L0_ROW_64(1)
    // `PRINT_L0_ROW_64(2)
    // `PRINT_L0_ROW_64(3)
    // `PRINT_L0_ROW_64(4)
    // `PRINT_L0_ROW_64(5)
    // `PRINT_L0_ROW_64(6)
    // `PRINT_L0_ROW_64(7)

    // `undef PRINT_L0_ROW_64 // Clean up
    
    // $display("----------------------------------------------------------\n");
    // $finish;
    /////////////////////////////////////



    //////// OFIFO READ ////////
    // Ideally, OFIFO should be read while execution, but we have enough ofifo
    // depth so we can fetch out after execution.

    // THIS SECTION HAS BEEN MOVED TO EXECUTION SECTOIN FOR BETTER PARALLELISM AND EFFICIENCY
    /////////////////////////////////////////////////
    // -----------------------------------------------------------------------

    // VISUAL VERIFICATION OF XMEM CONTENTS
    // -----------------------------------------------------------------------
    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
    // VISUAL VERIFICATION OF PMEM CONTENTS
    // -----------------------------------------------------------------------
    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF PSUM Loading to PMEM ");
    // $display("// -----------------------------------------------------------------------");
    // $display("\ PSUM data loaded into PMEM (Addresses 0 to %0d):", len_nij-1);
    // $display("Addr | Bank0 Lower16 | Bank0 Upper16 | Bank1 Lower16 | Bank1 Upper16 | Bank2 Lower16 | Bank2 Upper16 | Bank3 Lower16 | Bank3 Upper16 ");
    // $display("-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------");

   

    // for (i = 0; i < len_nij; i = i + 1) begin
    //     ind = i + len_nij*kij;
    //     // Read 32-bit words from each bank
    //     bank0_word = core_instance.pmem_row[0].pmem_instance.memory[ind];
    //     bank1_word = core_instance.pmem_row[1].pmem_instance.memory[ind];
    //     bank2_word = core_instance.pmem_row[2].pmem_instance.memory[ind];
    //     bank3_word = core_instance.pmem_row[3].pmem_instance.memory[ind];
        
    //     // Split each 32-bit word into signed 16-bit halves
    //     bank0_lower = $signed(bank0_word[15:0]);
    //     bank0_upper = $signed(bank0_word[31:16]);
    //     bank1_lower = $signed(bank1_word[15:0]);
    //     bank1_upper = $signed(bank1_word[31:16]);
    //     bank2_lower = $signed(bank2_word[15:0]);
    //     bank2_upper = $signed(bank2_word[31:16]);
    //     bank3_lower = $signed(bank3_word[15:0]);
    //     bank3_upper = $signed(bank3_word[31:16]);
        
    //     $display("%4d | %d        | %d        | %d        | %d        | %d        | %d        | %d        | %d       \n",
    //             ind,
    //             bank0_lower, 
    //             bank0_upper, 
    //             bank1_lower, 
    //             bank1_upper, 
    //             bank2_lower, 
    //             bank2_upper, 
    //             bank3_lower, 
    //             bank3_upper);
    //     $display("A_pmem: %d", A_pmem_q);
    // end
    // $display("----------------------------------------------------------------------------------------------------------------------------");

    /////////////////////////////////////


  end  // end of kij loop
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
   
  ////////// Accumulation /////////
  out_file = $fopen("text_files/2bit/out.txt", "r");  
  acc_file = $fopen("text_files/acc_file.txt", "r");  


  // Following three lines are to remove the first three comment lines of the file
  out_scan_file = $fscanf(out_file,"%s", captured_data); 
  out_scan_file = $fscanf(out_file,"%s", captured_data); 
  out_scan_file = $fscanf(out_file,"%s", captured_data); 

  error = 0;



  $display("############ Verification Start during accumulation #############"); 

  for (i=0; i<len_onij+1; i=i+1) begin 

    #0.5 clk = 1'b0; 
    #0.5 clk = 1'b1; 

    if (i>0) begin
     out_scan_file = $fscanf(out_file,"%128b", answer); // reading from out file to answer
       if (sfp_out == answer)
         $display("%2d-th output featuremap Data matched! :D", i); 
       else begin
         $display("%2d-th output featuremap Data ERROR!!", i); 
         $display("sfpout: %128b, %d", sfp_out, $signed(sfp_out[15:0]));
         $display("answer: %128b, %d", answer, $signed(answer[15:0]));
         error = 1;
       end
    end
   
    relu = 0;
    #0.5 clk = 1'b0; reset = 1; out_scan_file = $fscanf(out_file,"%128b", answer); // reading from out file to answer
    #0.5 clk = 1'b1;  
    #0.5 clk = 1'b0; reset = 0; 
    #0.5 clk = 1'b1;  

    for (j=0; j<len_kij+1; j=j+1) begin 

      #0.5 clk = 1'b0;   
        if (j<len_kij) begin 
          CEN_pmem = 0; WEN_pmem = 1; 
          acc_scan_file = $fscanf(acc_file,"%11b", A_pmem); 
          end
                       
        else  begin 
          CEN_pmem = 1; WEN_pmem = 1; 
        end

        // there is a 2 cycle delay for memory load, so if 
        // we turned acc on like they had before at j>0, then
        // the SFU starts adding with x, which results in x
        if (j>1)  acc = 1;  
      #0.5 clk = 1'b1;   
      // ---------------------------------------------------------
      // VISUALIZATION: SFU Inputs and Outputs
      // ---------------------------------------------------------
      // $display("Time: %0t | j: %0d | Acc: %b | A_pmem: %d", $time, j, acc, A_pmem);
      
      // // Display Column 0 details (easier to read than all 8 columns)
      // // core_instance.q_pmem is the data coming FROM memory -> INTO SFU
      // $display("  [Col 0] In (from Mem): %6d (Hex: %4h)", 
      //          $signed(core_instance.q_pmem[15:0]), core_instance.q_pmem[15:0]);
               
      // // sfp_out is the current value stored in the SFU Accumulator
      // $display("  [Col 0] SFU Accumulator: %6d (Hex: %4h)", 
      //          $signed(sfp_out[15:0]), sfp_out[15:0]);
               
      // $display("---------------------------------------------------");
      // ---------------------------------------------------------

    end
    
    #0.5 clk = 1'b0; acc = 0; 
    // Not sure on this yet, the out.txt is without relu, 
    // so if we turn relu on here the answer is wrong
    relu = 0;

    #0.5 clk = 1'b1; 
  end


  if (error == 0) begin
  	$display("############ No error detected ##############"); 
  	$display("########### Project Completed !! ############"); 

  end

  $fclose(acc_file);
  //////////////////////////////////

  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

 // #10 $finish;




// THIS PART IS FOR THE OTHER OUTPUT CHANNELS

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1;
  WEN_xmem = 1;
  A_xmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;
  two_bit_mode = 0;
  load_b2 = 0;
  A_pmem = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  x_file = $fopen("text_files/2bit/activation.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   
  /////////////////////////

  /////// Activation data writing to memory ///////
  for (t=0; t<len_nij; t=t+1) begin  
    #0.5 clk = 1'b0;  
    x_scan_file = $fscanf(x_file,"%32b", D_xmem); 
    WEN_xmem = 0; 
    CEN_xmem = 0; 
    if (t>0) A_xmem = A_xmem + 1;
    #0.5 clk = 1'b1;   
  end

  #0.5 clk = 1'b0;  
  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1; 

  $fclose(x_file);
  /////////////////////////////////////////////////
  // -----------------------------------------------------------------------

  // VISUAL VERIFICATION OF XMEM CONTENTS
  // -----------------------------------------------------------------------
  // Need one more clk cycle for the last write to show up vitually on SRAM 
  // #0.5 clk = 1'b0;   
  // #0.5 clk = 1'b1;   
  // $display("// -----------------------------------------------------------------------");
  //   $display("// VISUAL VERIFICATION OF Act Loading to XMEM CONTENTS");
  //   $display("// -----------------------------------------------------------------------");
  // $display("\nActivation data loaded into XMEM (Addresses 0 to %0d):", len_nij-1);
  // $display("Addr | Binary                           | Hex");
  // $display("-----|----------------------------------|---------");
  
  // for (i = 0; i < len_nij; i = i + 1) begin
  //     // NOTE: 'mem' must match the variable name of the reg array inside sram_32b_w2048.v
  //     // If it is named 'memory' or 'ram', change .mem[i] to .memory[i]
  //     $display("%4d | %b | %h \n", i, core_instance.xmem_inst.memory[i], core_instance.xmem_inst.memory[i]);
  // end
  // $display("----------------------------------------------------------\n");


  /////// Kernel weight writing to memory ///////
  for (kij=0; kij<9; kij=kij+1) begin  // kij loop

    // Note: added to the path to suit my directory structure, might need to change back for grading
    case(kij)
     0: w_file_name = "text_files/2bit/weight_itile0_otile0_kij0.txt";
     1: w_file_name = "text_files/2bit/weight_itile0_otile0_kij1.txt";
     2: w_file_name = "text_files/2bit/weight_itile0_otile0_kij2.txt";
     3: w_file_name = "text_files/2bit/weight_itile0_otile0_kij3.txt";
     4: w_file_name = "text_files/2bit/weight_itile0_otile0_kij4.txt";
     5: w_file_name = "text_files/2bit/weight_itile0_otile0_kij5.txt";
     6: w_file_name = "text_files/2bit/weight_itile0_otile0_kij6.txt";
     7: w_file_name = "text_files/2bit/weight_itile0_otile0_kij7.txt";
     8: w_file_name = "text_files/2bit/weight_itile0_otile0_kij8.txt";
    endcase
   
    $display("%s", w_file_name);

    w_file = $fopen(w_file_name, "r");
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    // also remove the first 8 lines since we already computed those output channels
    w_scan_file = $fscanf(w_file,"%64b", captured_data);
    w_scan_file = $fscanf(w_file,"%64b", captured_data);
    w_scan_file = $fscanf(w_file,"%64b", captured_data);
    w_scan_file = $fscanf(w_file,"%64b", captured_data);
    w_scan_file = $fscanf(w_file,"%64b", captured_data);
    w_scan_file = $fscanf(w_file,"%64b", captured_data);
    w_scan_file = $fscanf(w_file,"%64b", captured_data);
    w_scan_file = $fscanf(w_file,"%64b", captured_data);

    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1; 

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   



    /////// Kernel data writing to memory ///////

    // Using the same SRAM for weight and act
    A_xmem = 11'b10000000000; // Starts at a higher address (1024) so activation has enough space

    for (t=0; t<col*2; t=t+1) begin  // 2 BIT: 16 input channels * 4 bits = 64 bits. Need 2 rows of 32bit SRAM to store 64 bits. Also there are 16 output channels. 16*2 = 32 = 8*4
      if (t%2 == 0) begin
        w_scan_file = $fscanf(w_file,"%64b", weight_mem);
      end 
      #0.5 clk = 1'b0;  
      if (t%2==0) begin
        D_xmem = weight_mem_2;
      end
      else begin
        D_xmem = weight_mem_1;
      end
      WEN_xmem = 0; 
      CEN_xmem = 0; 
      if (t>0) A_xmem = A_xmem + 8*(t%2);
      if (t>0 && (t%2==0)) A_xmem = A_xmem - 8 + 1; 
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1; 
    $fclose(w_file);
    /////////////////////////////////////
    // VISUAL VERIFICATION OF XMEM CONTENTS (Only Kij = 1)
    //-----------------------------------------------------------------------
    //Need one more clk cycle for the last write to show up vitually on SRAM 
    // #0.5 clk = 1'b0;   
    // #0.5 clk = 1'b1;   
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF Kernel Loading to XMEM CONTENTS");
    // $display("// -----------------------------------------------------------------------");
    // $display("\nKernel weights (kij) loaded into XMEM (Addresses 1024 to %0d):", 1024+col*2-1);
    // $display("Addr | Binary                           | Hex");
    // $display("-----|----------------------------------|---------");
    //
    // for (i = 1024; i < (col*4 + 1024); i = i + 1) begin
    //     // NOTE: 'mem' must match the variable name of the reg array inside sram_32b_w2048.v
    //     // If it is named 'memory' or 'ram', change .mem[i] to .memory[i]
    //     $display("%4d | %b | %h \n", i, core_instance.xmem_inst.memory[i], core_instance.xmem_inst.memory[i]);
    // end
    // $display("----------------------------------------------------------\n");
    //$finish;
    
    /////// Kernel data writing to L0 ///////
    // Need to send to memory 1 cycle earlier as it has 1 cycle higher wait
    #0.5 clk = 1'b0;   
    A_xmem = 1024; // Read from proper address, kij at 1024 to 1031
    WEN_xmem = 1;  
    CEN_xmem = 0;
    #0.5 clk = 1'b1;  

    for (t=0; t<col*2; t=t+1)begin // 2 BIT: 16 output channels * 4 bits = 64 bits. Need 2 rows of 32bit SRAM to store 64 bits. Total is 32 rows, but only 16 are written for now since there's only 16 weight registers in a row
      //Prepare SRAM to be read
      #0.5 clk = 1'b0;  
      WEN_xmem = 1;  
      CEN_xmem = 0;
      // Enable L0 write
      l0_wr = 1; 
      l0_rd = 0;

      A_xmem = A_xmem + 1; 
      #0.5 clk = 1'b1; 

    end
    
    #0.5 clk = 1'b0; WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    l0_wr = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////

    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    // -----------------------------------------------------------------------
    // VISUAL VERIFICATION OF L0 FIFO CONTENTS
    // -----------------------------------------------------------------------
  //   $display("// -----------------------------------------------------------------------");
  //   $display("// VISUAL VERIFICATION OF L0 FIFO CONTENTS");
  //   $display("// -----------------------------------------------------------------------");
  //   $display("\nL0 FIFO Contents (First %0d words per row):", col);
  //   $display("Row | Depth | Value (Hex)");
  //   $display("----|-------|-------------");

  //   `define PRINT_L0_ROW(ROW_IDX) \
  //       $display(" %2d |   0  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q0); \
  //       $display(" %2d |   1  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q1); \
  //       $display(" %2d |   2  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q2); \
  //       $display(" %2d |   3  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q3); \
  //       $display(" %2d |   4  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q4); \
  //       $display(" %2d |   5  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q5); \
  //       $display(" %2d |   6  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q6); \
  //       $display(" %2d |   7  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q7); \
	// $display(" %2d |   8  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q8); \
  //       $display(" %2d |   9  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q9); \
  //       $display(" %2d |   10  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q10); \
  //       $display(" %2d |   11  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q11); \
  //       $display(" %2d |   12  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q12); \
  //       $display(" %2d |   13  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q13); \
  //       $display(" %2d |   14  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q14); \
  //       $display(" %2d |   15  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q15); \
  //       $display("----|-------|-------------");\
  //       $display(" Write_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.wr_ptr); \
  //       $display(" Read_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.rd_ptr); \
  //       $display("----|-------|-------------");\

  //   //Manually call the macro for each row
  //   `PRINT_L0_ROW(0)
  //   `PRINT_L0_ROW(1)
  //   `PRINT_L0_ROW(2)
  //   `PRINT_L0_ROW(3)
  //   `PRINT_L0_ROW(4)
  //   `PRINT_L0_ROW(5)
  //   `PRINT_L0_ROW(6)
  //   `PRINT_L0_ROW(7)

  //   `undef PRINT_L0_ROW // Clean up
  //   $display("----------------------------------------------------------\n");
    // -----------------------------------------------------------------------
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    //$finish;
    /////// Kernel loading to PEs ///////
    
    // Helper Macros for Visualization
    // Adjust 'mac_array_instance', 'col_num', 'w_q', 'a_q' if your names differ
    `define TILE(R, C) core_instance.corelet_instance.mac_array_instance.row_num[R].mac_row_instance.col_num[C].mac_tile_instance
    
    `define PRINT_MAC_ROW(R) \
    $display("R%0d | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h | %h %h %h |", R, \
       `TILE(R,1).b_q, `TILE(R,1).b2_q, `TILE(R,1).a_q, \
       `TILE(R,2).b_q, `TILE(R,2).b2_q, `TILE(R,2).a_q, \
       `TILE(R,3).b_q, `TILE(R,3).b2_q, `TILE(R,3).a_q, \
       `TILE(R,4).b_q, `TILE(R,4).b2_q, `TILE(R,4).a_q, \
       `TILE(R,5).b_q, `TILE(R,5).b2_q, `TILE(R,5).a_q, \
       `TILE(R,6).b_q, `TILE(R,6).b2_q, `TILE(R,6).a_q, \
       `TILE(R,7).b_q, `TILE(R,7).b2_q, `TILE(R,7).a_q, \
       `TILE(R,8).b_q, `TILE(R,8).b2_q, `TILE(R,8).a_q);

    
    // L0 read enable logic
    for (t=0; t<col+row*2; t=t+1) begin  // col+row*2 because that is the total cycle to populate the array
      #0.5 clk = 1'b0;   load_b2 = 0; two_bit_mode = 1;
      // Only need to send inst_w once, as it gets passed
      if (t == 0)begin
        load = 1;
        execute = 0;
      end
      // After col number of cycles, first fifo in l0 would be empty
      // so we need to shut it down. The shut down signal propapages to the next
      // fifo columns in l0 automatically cycle by cycle (check l0 code)
      if (t < col)begin
        l0_rd = 1;
      end
      else begin
        l0_rd = 0;
      end
      #0.5 clk = 1'b1;  

      // --- VISUALIZATION BLOCK ---
      // $display("\nCycle %0d: MAC Array State [Weight Activation]", t);
      // $display("   | C0      | C1      | C2      | C3      | C4      | C5      | C6      | C7      |");
      // $display("---|---------|---------|---------|---------|---------|---------|---------|---------|");
      // `PRINT_MAC_ROW(1)
      // `PRINT_MAC_ROW(2)
      // `PRINT_MAC_ROW(3)
      // `PRINT_MAC_ROW(4)
      // `PRINT_MAC_ROW(5)
      // `PRINT_MAC_ROW(6)
      // `PRINT_MAC_ROW(7)
      // `PRINT_MAC_ROW(8)

      // $display("----------------------------------------------------------------------------------");
    //   // ---------------------------
    end
    // Extra cycle for the last PE to store the weight
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;
    l0_rd = 0;
    load = 0;
    execute = 0;
    #0.5 clk = 1'b1;
    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<30 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end
    /////////////////////////////////////


    for (t=0; t<col+row*2; t=t+1) begin  // col+row*2 because that is the total cycle to populate the array
      #0.5 clk = 1'b0;   load_b2 = 1; two_bit_mode = 1;
      // Only need to send inst_w once, as it gets passed
      if (t == 0)begin
        load = 1;
        execute = 0;
      end
      // After col number of cycles, first fifo in l0 would be empty
      // so we need to shut it down. The shut down signal propapages to the next
      // fifo columns in l0 automatically cycle by cycle (check l0 code)
      if (t < col)begin
        l0_rd = 1;
      end
      else begin
        l0_rd = 0;
      end
      #0.5 clk = 1'b1;  

      // --- VISUALIZATION BLOCK ---
      // $display("\nCycle %0d: MAC Array State [Weight Activation]", t);
      // $display("   | C0      | C1      | C2      | C3      | C4      | C5      | C6      | C7      |");
      // $display("---|---------|---------|---------|---------|---------|---------|---------|---------|");
      // `PRINT_MAC_ROW(1)
      // `PRINT_MAC_ROW(2)
      // `PRINT_MAC_ROW(3)
      // `PRINT_MAC_ROW(4)
      // `PRINT_MAC_ROW(5)
      // `PRINT_MAC_ROW(6)
      // `PRINT_MAC_ROW(7)
      // `PRINT_MAC_ROW(8)

      // $display("----------------------------------------------------------------------------------");
    //   // ---------------------------
    end

    // Extra cycle for the last PE to store the weight
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0; 
    l0_rd = 0;
    load = 0;
    execute = 0;
    #0.5 clk = 1'b1;
     // --- VISUALIZATION BLOCK FOR COMPLETED LOAD---
      // $display("\nAfter Loading Finished: MAC Array State [Weight Activation]");
      // $display("   | C0      | C1      | C2      | C3      | C4      | C5      | C6      | C7      |");
      // $display("---|---------|---------|---------|---------|---------|---------|---------|---------|");
      // `PRINT_MAC_ROW(1)
      // `PRINT_MAC_ROW(2)
      // `PRINT_MAC_ROW(3)
      // `PRINT_MAC_ROW(4)
      // `PRINT_MAC_ROW(5)
      // `PRINT_MAC_ROW(6)
      // `PRINT_MAC_ROW(7)
      // `PRINT_MAC_ROW(8)

      // $display("----------------------------------------------------------------------------------");
      // ---------------------------

    // Clean up macros
    `undef TILE
    `undef PRINT_MAC_ROW
    //$finish;
    /////////////////////////////////////
  
  // NOTE on previous two parts:
  // If we want to do parallel L0 writing and PE loading, 
  // we would have to port the L0 o_ready, and o_full signals to the testbench
  // This way if L0 is full, we would have the memory wait extra cycles
  // Which is not done in the current setup, 
  // Since we currently will never run out of room in L0 doing this sequentially
  // with no parallelism 


    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end
    /////////////////////////////////////



    /////// Activation data writing to L0 ///////
    // Need to send to memory 1 cycle earlier as it has 1 cycle higher wait
    #0.5 clk = 1'b0;   
    A_xmem = 0; // Read from proper address, starting from 0 for activation
    WEN_xmem = 1;  
    CEN_xmem = 0;
    #0.5 clk = 1'b1;  

    for (t=0; t<len_nij; t=t+1)begin
      //Prepare SRAM to be read
      #0.5 clk = 1'b0;  
      WEN_xmem = 1;  
      CEN_xmem = 0;
      // Enable L0 write
      l0_wr = 1; 
      l0_rd = 0;

      A_xmem = A_xmem + 1; 
      #0.5 clk = 1'b1; 

    end
    
    #0.5 clk = 1'b0; WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    l0_wr = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////

    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    // -----------------------------------------------------------------------
    // VISUAL VERIFICATION OF L0 FIFO CONTENTS
    // -----------------------------------------------------------------------
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF L0 FIFO CONTENTS (X)");
    // $display("// -----------------------------------------------------------------------");
    // $display("\nL0 FIFO Contents (First %0d words per row):", col);
    // $display("Row | Depth | Value (Hex)");
    // $display("----|-------|-------------");

    // `define PRINT_L0_ROW_64(ROW_IDX) \
    // $display(" %2d |  0  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q16); \
    // $display(" %2d |  1  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q17); \
    // $display(" %2d |  2  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q18); \
    // $display(" %2d |  3  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q19); \
    // $display(" %2d |  4  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q20); \
    // $display(" %2d |  5  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q21); \
    // $display(" %2d |  6  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q22); \
    // $display(" %2d |  7  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q23); \
    // $display(" %2d |  8  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q24); \
    // $display(" %2d |  9  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q25); \
    // $display(" %2d | 10  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q26); \
    // $display(" %2d | 11  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q27); \
    // $display(" %2d | 12  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q28); \
    // $display(" %2d | 13  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q29); \
    // $display(" %2d | 14  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q30); \
    // $display(" %2d | 15  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q31); \
    // $display(" %2d | 16  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q32); \
    // $display(" %2d | 17  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q33); \
    // $display(" %2d | 18  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q34); \
    // $display(" %2d | 19  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q35); \
    // $display(" %2d | 20  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q36); \
    // $display(" %2d | 21  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q37); \
    // $display(" %2d | 22  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q38); \
    // $display(" %2d | 23  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q39); \
    // $display(" %2d | 24  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q40); \
    // $display(" %2d | 25  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q41); \
    // $display(" %2d | 26  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q42); \
    // $display(" %2d | 27  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q43); \
    // $display(" %2d | 28  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q44); \
    // $display(" %2d | 29  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q45); \
    // $display(" %2d | 30  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q46); \
    // $display(" %2d | 31  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q47); \
    // $display(" %2d | 32  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q48); \
    // $display(" %2d | 33  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q49); \
    // $display(" %2d | 34  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q50); \
    // $display(" %2d | 35  | %h", ROW_IDX, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q51); \
    // $display("----|-------|-------------");\
    // $display(" Write_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.wr_ptr); \
    // $display(" Read_pointer | %b", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.rd_ptr); \
    // $display("----|-------|-------------");

    // // Manually call the macro for each row
    // `PRINT_L0_ROW_64(0)
    // `PRINT_L0_ROW_64(1)
    // `PRINT_L0_ROW_64(2)
    // `PRINT_L0_ROW_64(3)
    // `PRINT_L0_ROW_64(4)
    // `PRINT_L0_ROW_64(5)
    // `PRINT_L0_ROW_64(6)
    // `PRINT_L0_ROW_64(7)

    // `undef PRINT_L0_ROW_64 // Clean up
    
    // $display("----------------------------------------------------------\n");
    //$finish;
    // -----------------------------------------------------------------------
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    /////////////////////////////////////



    /////// Execution ///////
    // OFIFO has 64 depth, each of them is enough to store all
    // outputs for 1 kij. Which is the number of nij = 36.

    // OFIFO read enable logic
    for (t=0; t<len_nij+row*2+1; t=t+1) begin  // col+row*2 because that is the total cycle to populate the array
      #0.5 clk = 1'b0;   
      // Only need to send inst_w once, as it gets passed
      
      // After nij number of cycles, first fifo in l0 would be empty
      // so we need to shut it down. The shut down signal propapages to the next
      // fifo columns in l0 automatically cycle by cycle (check l0 code)
      if (t < len_nij)begin
        l0_rd = 1; // send from l0
        load = 0;
        execute = 1;
      end
      else begin
        l0_rd = 0;
        load = 0;
        execute = 0;
      end

      // OFIFO to PMEM in parallel with execution to OFIFO
      if (t > row*2) begin
        // ofifo read enable
        ofifo_rd = 1;
        // Write signals to pmem
        WEN_pmem = 0; 
        CEN_pmem = 0; 
        if (t>row*2 + 1) A_pmem = A_pmem + 1;
      end
      else if (t == row*2) begin
        // Need this line so that the timing of memory write and ofifo read is right
        ofifo_rd = 1; 
      end

      #0.5 clk = 1'b1;  
      // Verify that OFIFO never gets full and the pointers behave properly
      // $display("// -----------------------------------------------------------------------");
      // $display("// VISUAL VERIFICATION OF OFIFO POINTERS");
      // $display("// -----------------------------------------------------------------------");
      // $display("| Write Ptr | Read Ptr");
      // $display("|-----------|----------");
      //     $display("|    %2d     |   %2d", 
      //         core_instance.corelet_instance.ofifo_instance.col_num[0].fifo_instance.wr_ptr, 
      //         core_instance.corelet_instance.ofifo_instance.col_num[0].fifo_instance.rd_ptr
      //     );
      // $display("----------------------------------------------------------\n");

    end

    #0.5 clk = 1'b0;  
    WEN_pmem = 1;  CEN_pmem = 1; ofifo_rd = 0; 
    // This makes sure we write to the next address instead of overwriting the end of this kij
    A_pmem = A_pmem + 1;

    #0.5 clk = 1'b1; 
    
    // Need two more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;  
    // -----------------------------------------------------------------------
    // VISUAL VERIFICATION OF L0 FIFO CONTENTS
    // -----------------------------------------------------------------------
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF OFIFO CONTENTS");
    // $display("// -----------------------------------------------------------------------");
    // $display("\n OFIFO Contents (First %0d words per row):", col);
    // $display("Row | Depth | Value (Hex)");
    // $display("----|-------|-------------");

    // `define PRINT_L0_ROW_64(ROW_IDX) \
    // $display(" %2d |  0  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q0)); \
    // $display(" %2d |  1  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q1)); \
    // $display(" %2d |  2  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q2)); \
    // $display(" %2d |  3  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q3)); \
    // $display(" %2d |  4  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q4)); \
    // $display(" %2d |  5  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q5)); \
    // $display(" %2d |  6  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q6)); \
    // $display(" %2d |  7  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q7)); \
    // $display(" %2d |  8  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q8)); \
    // $display(" %2d |  9  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q9)); \
    // $display(" %2d | 10  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q10)); \
    // $display(" %2d | 11  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q11)); \
    // $display(" %2d | 12  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q12)); \
    // $display(" %2d | 13  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q13)); \
    // $display(" %2d | 14  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q14)); \
    // $display(" %2d | 15  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q15)); \
    // $display(" %2d | 16  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q16)); \
    // $display(" %2d | 17  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q17)); \
    // $display(" %2d | 18  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q18)); \
    // $display(" %2d | 19  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q19)); \
    // $display(" %2d | 20  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q20)); \
    // $display(" %2d | 21  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q21)); \
    // $display(" %2d | 22  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q22)); \
    // $display(" %2d | 23  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q23)); \
    // $display(" %2d | 24  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q24)); \
    // $display(" %2d | 25  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q25)); \
    // $display(" %2d | 26  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q26)); \
    // $display(" %2d | 27  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q27)); \
    // $display(" %2d | 28  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q28)); \
    // $display(" %2d | 29  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q29)); \
    // $display(" %2d | 30  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q30)); \
    // $display(" %2d | 31  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q31)); \
    // $display(" %2d | 32  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q32)); \
    // $display(" %2d | 33  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q33)); \
    // $display(" %2d | 34  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q34)); \
    // $display(" %2d | 35  | %d", ROW_IDX, $signed(core_instance.corelet_instance.ofifo_instance.col_num[ROW_IDX].fifo_instance.q35)); \

    // // Manually call the macro for each row
    // `PRINT_L0_ROW_64(0)
    // `PRINT_L0_ROW_64(1)
    // `PRINT_L0_ROW_64(2)
    // `PRINT_L0_ROW_64(3)
    // `PRINT_L0_ROW_64(4)
    // `PRINT_L0_ROW_64(5)
    // `PRINT_L0_ROW_64(6)
    // `PRINT_L0_ROW_64(7)

    // `undef PRINT_L0_ROW_64 // Clean up
    
    // $display("----------------------------------------------------------\n");
    //$finish;
    /////////////////////////////////////



    //////// OFIFO READ ////////
    // Ideally, OFIFO should be read while execution, but we have enough ofifo
    // depth so we can fetch out after execution.

    // THIS SECTION HAS BEEN MOVED TO EXECUTION SECTOIN FOR BETTER PARALLELISM AND EFFICIENCY


    /////////////////////////////////////////////////
    // -----------------------------------------------------------------------

    // VISUAL VERIFICATION OF XMEM CONTENTS
    // -----------------------------------------------------------------------
    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
    // VISUAL VERIFICATION OF PMEM CONTENTS
    // -----------------------------------------------------------------------
    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF PSUM Loading to PMEM ");
    // $display("// -----------------------------------------------------------------------");
    // $display("\ PSUM data loaded into PMEM (Addresses 0 to %0d):", len_nij-1);
    // $display("Addr | Bank0 Lower16 | Bank0 Upper16 | Bank1 Lower16 | Bank1 Upper16 | Bank2 Lower16 | Bank2 Upper16 | Bank3 Lower16 | Bank3 Upper16 ");
    // $display("-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------");

   

    // for (i = 0; i < len_nij; i = i + 1) begin
    //     ind = i + len_nij*kij;
    //     // Read 32-bit words from each bank
    //     bank0_word = core_instance.pmem_row[0].pmem_instance.memory[ind];
    //     bank1_word = core_instance.pmem_row[1].pmem_instance.memory[ind];
    //     bank2_word = core_instance.pmem_row[2].pmem_instance.memory[ind];
    //     bank3_word = core_instance.pmem_row[3].pmem_instance.memory[ind];
        
    //     // Split each 32-bit word into signed 16-bit halves
    //     bank0_lower = $signed(bank0_word[15:0]);
    //     bank0_upper = $signed(bank0_word[31:16]);
    //     bank1_lower = $signed(bank1_word[15:0]);
    //     bank1_upper = $signed(bank1_word[31:16]);
    //     bank2_lower = $signed(bank2_word[15:0]);
    //     bank2_upper = $signed(bank2_word[31:16]);
    //     bank3_lower = $signed(bank3_word[15:0]);
    //     bank3_upper = $signed(bank3_word[31:16]);
        
    //     $display("%4d | %d        | %d        | %d        | %d        | %d        | %d        | %d        | %d       \n",
    //             ind,
    //             bank0_lower, 
    //             bank0_upper, 
    //             bank1_lower, 
    //             bank1_upper, 
    //             bank2_lower, 
    //             bank2_upper, 
    //             bank3_lower, 
    //             bank3_upper);
    //     $display("A_pmem: %d", A_pmem_q);
    // end
    // $display("----------------------------------------------------------------------------------------------------------------------------");

    /////////////////////////////////////


  end  // end of kij loop
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
   
  ////////// Accumulation /////////
  out_file = $fopen("text_files/2bit/out.txt", "r");  
  acc_file = $fopen("text_files/acc_file.txt", "r");  


  // Following three lines are to remove the first three comment lines of the file
  out_scan_file = $fscanf(out_file,"%s", captured_data); 
  out_scan_file = $fscanf(out_file,"%s", captured_data); 
  out_scan_file = $fscanf(out_file,"%s", captured_data); 

  error = 0;



  $display("############ Verification Start during accumulation #############"); 

  for (i=0; i<len_onij+1; i=i+1) begin 

    #0.5 clk = 1'b0; 
    #0.5 clk = 1'b1; 

    if (i>0) begin
     out_scan_file = $fscanf(out_file,"%128b", answer); // reading from out file to answer
       if (sfp_out == answer)
         $display("%2d-th output featuremap Data matched! :D", i); 
       else begin
         $display("%2d-th output featuremap Data ERROR!!", i); 
         $display("sfpout: %128b, %d", sfp_out, $signed(sfp_out[15:0]));
         $display("answer: %128b, %d", answer, $signed(answer[15:0]));
         error = 1;
       end
    end
   
    relu = 0;
    #0.5 clk = 1'b0; reset = 1; 
    #0.5 clk = 1'b1;  
    #0.5 clk = 1'b0; reset = 0; if (i>0) out_scan_file = $fscanf(out_file,"%128b", answer); // skips to other half to comparison
    #0.5 clk = 1'b1;  

    for (j=0; j<len_kij+1; j=j+1) begin 

      #0.5 clk = 1'b0;   
        if (j<len_kij) begin 
          CEN_pmem = 0; WEN_pmem = 1; 
          acc_scan_file = $fscanf(acc_file,"%11b", A_pmem); 
          end
                       
        else  begin 
          CEN_pmem = 1; WEN_pmem = 1; 
        end

        // there is a 2 cycle delay for memory load, so if 
        // we turned acc on like they had before at j>0, then
        // the SFU starts adding with x, which results in x
        if (j>1)  acc = 1;  
      #0.5 clk = 1'b1;   
      // ---------------------------------------------------------
      // VISUALIZATION: SFU Inputs and Outputs
      // ---------------------------------------------------------
      // $display("Time: %0t | j: %0d | Acc: %b | A_pmem: %d", $time, j, acc, A_pmem);
      
      // // Display Column 0 details (easier to read than all 8 columns)
      // // core_instance.q_pmem is the data coming FROM memory -> INTO SFU
      // $display("  [Col 0] In (from Mem): %6d (Hex: %4h)", 
      //          $signed(core_instance.q_pmem[15:0]), core_instance.q_pmem[15:0]);
               
      // // sfp_out is the current value stored in the SFU Accumulator
      // $display("  [Col 0] SFU Accumulator: %6d (Hex: %4h)", 
      //          $signed(sfp_out[15:0]), sfp_out[15:0]);
               
      // $display("---------------------------------------------------");
      // ---------------------------------------------------------

    end
    
    #0.5 clk = 1'b0; acc = 0; 
    // Not sure on this yet, the out.txt is without relu, 
    // so if we turn relu on here the answer is wrong
    relu = 0;

    #0.5 clk = 1'b1; 
  end


  if (error == 0) begin
  	$display("############ No error detected ##############"); 
  	$display("########### Project Completed !! ############"); 

  end

  $fclose(acc_file);
  //////////////////////////////////

  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

  #10 $finish;





end

always @ (posedge clk) begin
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
   CEN_xmem_q <= CEN_xmem;
   WEN_xmem_q <= WEN_xmem;
   A_pmem_q   <= A_pmem;
   CEN_pmem_q <= CEN_pmem;
   WEN_pmem_q <= WEN_pmem;
   A_xmem_q   <= A_xmem;
   ofifo_rd_q <= ofifo_rd;
   acc_q      <= acc;
   relu_q     <= relu;
   ififo_wr_q <= ififo_wr;
   ififo_rd_q <= ififo_rd;
   l0_rd_q    <= l0_rd;
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;
   mode_sel_q <= mode_sel;
   os_out_q   <= os_out;
   two_bit_mode_q <= two_bit_mode;
   load_b2_q <= load_b2;
end


endmodule




