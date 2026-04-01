
`timescale 1ns/1ps

module core_os_2bit_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9;
parameter len_onij = 16;
parameter col = 8;
parameter row = 8;
parameter len_nij = 36;
parameter in_ch = 16;
parameter out_ch = 16;

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
reg [bw*row*2-1:0] D_xmem;
reg [bw*row-1:0] temp_D_xmem;
reg [len_nij*bw-1:0] act_cache; // NEW: Vector to store 36 nijs for reading a whole file column (144 bits)
reg [psum_bw*col*2-1:0] answer;


reg ofifo_rd;
reg ififo_wr;
reg ififo_rd;
reg l0_rd;
reg l0_wr;
reg execute;
reg load;
reg [8*30:1] stringvar;
reg [8*60:1] w_file_name;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, kij, ic, tile;
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
assign inst_q[5]   = ififo_wr_q; // read and write signals for ififo
assign inst_q[4]   = ififo_rd_q;
assign inst_q[3]   = l0_rd_q; // read and write signals for l0
assign inst_q[2]   = l0_wr_q;
assign inst_q[1]   = execute_q; // inst_w {execute, load}
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
  // used to read from all the memory lines as each output is stored across 16 memory lines
  reg [255:0] temp_answer [0:15]; // Array of 16 elements, each 256 bits wide




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
  mode_sel = 1; // output stationary
  os_out   = 0;
  two_bit_mode = 1;
  load_b2 = 0;

  $dumpfile("core_os_2bit_tb.vcd");
  $dumpvars(0, core_os_2bit_tb);

 

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

  for (tile = 0; tile<2; tile=tile+1) begin
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
    for (ic=0; ic<16; ic=ic+1) begin  // input channel loop (ic < 16)

      #0.5 clk = 1'b0;   
      #0.5 clk = 1'b1;  

      /////// Activation data writing to Xmem ///////

      x_file = $fopen("text_files/2bit/activation.txt", "r");

      // Following three lines are to remove the first three comment lines of the file
      x_scan_file = $fscanf(x_file,"%s", captured_data);
      x_scan_file = $fscanf(x_file,"%s", captured_data);
      x_scan_file = $fscanf(x_file,"%s", captured_data);


      // Reading file (original format txt file needs some manipulating, hence this loop)
      for (t=0; t<len_nij; t=t+1) begin  //iterate nij times to get all the rows
        // 1. Read the full 32-bit line from the file (which contains 8 distinct row values)
        x_scan_file = $fscanf(x_file,"%32b", D_xmem); 

        // 2. OUTPUT STATIONARY ADAPTATION (2-BIT MODE):
        // Take the 2 bits corresponding to Row ic (LSBs [ic*2 + :2]) and store into out temp storage.
        case(ic)
        0: act_cache[t*2 +: 2] = D_xmem[ 1: 0];
          1: act_cache[t*2 +: 2] = D_xmem[ 3: 2];
          2: act_cache[t*2 +: 2] = D_xmem[ 5: 4];
          3: act_cache[t*2 +: 2] = D_xmem[ 7: 6];
          4: act_cache[t*2 +: 2] = D_xmem[ 9: 8];
          5: act_cache[t*2 +: 2] = D_xmem[11:10];
          6: act_cache[t*2 +: 2] = D_xmem[13:12];
          7: act_cache[t*2 +: 2] = D_xmem[15:14];
          8: act_cache[t*2 +: 2] = D_xmem[17:16];
          9: act_cache[t*2 +: 2] = D_xmem[19:18];
          10: act_cache[t*2 +: 2] = D_xmem[21:20];
          11: act_cache[t*2 +: 2] = D_xmem[23:22];
          12: act_cache[t*2 +: 2] = D_xmem[25:24];
          13: act_cache[t*2 +: 2] = D_xmem[27:26];
          14: act_cache[t*2 +: 2] = D_xmem[29:28];
          15: act_cache[t*2 +: 2] = D_xmem[31:30];
        endcase
      end

      // --- VISUALIZATION: Print act_cache contents ---
      // $display("\n--- act_cache contents for Input Channel (ic) %0d ---", ic);
      // for (i = 0; i < len_nij; i = i + 1) begin
      //     // Prints each element labeled nij_0, nij_1, etc.
      //     // NOTE: Currently set to 4 bits to match your loop above. 
      //     // Change '4' to '2' if you are in 2-bit mode.
      //     $display("nij_%0d : Binary: %b | Dec: %d", i, act_cache[i*2 +: 2], $signed(act_cache[i*2 +: 2]));
      // end

      // Constructing the memory lines and writing
      for (t=0; t<len_kij; t=t+1) begin
        #0.5 clk = 1'b0;  

        // Calculate the base offset for the current kernel position 't' (0..8)
        // Input Width is 6.
                          // t=0,1,2 (Row 0 of kernel) -> Offsets 0,1,2
                          // t=3,4,5 (Row 1 of kernel) -> Offsets 6,7,8
                          // t=6,7,8 (Row 2 of kernel) -> Offsets 12,13,14
                          // Formula: (t/3)*6 + (t%3)

        // SIMD made it so that each PE can now do two seperate 2-bit act * 4 bit weight calculations
        // This means we can do two output_nij locations in parallel for each PE.
        D_xmem = { 
          // --- Row 7: Out(3,2) & Out(3,3) ---
          // Input Offsets: 20, 21 (Base + 3*6 + 2, Base + 3*6 + 3)
          act_cache[((t/3)*6 + (t%3) + 21)*2 +: 2], // MSB
          act_cache[((t/3)*6 + (t%3) + 20)*2 +: 2], // LSB

          // --- Row 6: Out(3,0) & Out(3,1) ---
          // Input Offsets: 18, 19 (Base + 3*6 + 0, Base + 3*6 + 1)
          act_cache[((t/3)*6 + (t%3) + 19)*2 +: 2], 
          act_cache[((t/3)*6 + (t%3) + 18)*2 +: 2], 

          // --- Row 5: Out(2,2) & Out(2,3) ---
          // Input Offsets: 14, 15 (Base + 2*6 + 2, Base + 2*6 + 3)
          act_cache[((t/3)*6 + (t%3) + 15)*2 +: 2], 
          act_cache[((t/3)*6 + (t%3) + 14)*2 +: 2], 

          // --- Row 4: Out(2,0) & Out(2,1) ---
          // Input Offsets: 12, 13 (Base + 2*6 + 0, Base + 2*6 + 1)
          act_cache[((t/3)*6 + (t%3) + 13)*2 +: 2], 
          act_cache[((t/3)*6 + (t%3) + 12)*2 +: 2], 

          // --- Row 3: Out(1,2) & Out(1,3) ---
          // Input Offsets: 8, 9 (Base + 1*6 + 2, Base + 1*6 + 3)
          act_cache[((t/3)*6 + (t%3) +  9)*2 +: 2], 
          act_cache[((t/3)*6 + (t%3) +  8)*2 +: 2], 

          // --- Row 2: Out(1,0) & Out(1,1) ---
          // Input Offsets: 6, 7 (Base + 1*6 + 0, Base + 1*6 + 1)
          act_cache[((t/3)*6 + (t%3) +  7)*2 +: 2], 
          act_cache[((t/3)*6 + (t%3) +  6)*2 +: 2], 

          // --- Row 1: Out(0,2) & Out(0,3) ---
          // Input Offsets: 2, 3 (Base + 0*6 + 2, Base + 0*6 + 3)
          act_cache[((t/3)*6 + (t%3) +  3)*2 +: 2], 
          act_cache[((t/3)*6 + (t%3) +  2)*2 +: 2], 

          // --- Row 0: Out(0,0) & Out(0,1) ---
          // Input Offsets: 0, 1 (Base + 0*6 + 0, Base + 0*6 + 1)
          act_cache[((t/3)*6 + (t%3) +  1)*2 +: 2], // MSB
          act_cache[((t/3)*6 + (t%3) +  0)*2 +: 2]
        };

        WEN_xmem = 0; 
        CEN_xmem = 0; 
        if (t>0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;  
      end

      #0.5 clk = 1'b0;  
      WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
      #0.5 clk = 1'b1; 

      $fclose(x_file);

      #0.5 clk = 1'b0;   
      #0.5 clk = 1'b1; 
      /////////////////////////////////////////////////


      // -----------------------------------------------------------------------

      // VISUAL VERIFICATION OF XMEM CONTENTS
      // -----------------------------------------------------------------------
      // Need one more clk cycle for the last write to show up vitually on SRAM 
        
      // $display("// -----------------------------------------------------------------------");
      // $display("// VISUAL VERIFICATION OF Act Loading to XMEM CONTENTS");
      // $display("// -----------------------------------------------------------------------");
      // $display("\nActivation data loaded into XMEM (Addresses 0 to %0d):", len_nij-1);
      // $display("Addr | Binary                           | Hex");
      // $display("-----|----------------------------------|---------");
      
      // for (i = 0; i < len_kij; i = i + 1) begin
      //     // NOTE: 'mem' must match the variable name of the reg array inside sram_32b_w2048.v
      //     // If it is named 'memory' or 'ram', change .mem[i] to .memory[i]
      //     $display("%4d | %b | %h \n", i, core_instance.xmem_inst.memory[i], core_instance.xmem_inst.memory[i]);
      // end
      // $display("----------------------------------------------------------\n");

      
      /////// Kernel weight writing to memory ///////

      // Using the same SRAM for weight and act
      A_xmem = 11'b10000000000; // Starts at a higher address (1024)
      #0.5 clk = 1'b0;   
      #0.5 clk = 1'b1; 

      // This loops to open all the kij files, since we need 
      // all kij (1 to 9) in one cycle of output stationary processing
      for (kij=0; kij<9; kij=kij+1) begin  // kij loop
        #0.5 clk = 1'b0;  

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
      
        // $display("%s", w_file_name);

        w_file = $fopen(w_file_name, "r");

        // Following three lines are to remove the first three comment lines of the file
        w_scan_file = $fscanf(w_file,"%s", captured_data);
        w_scan_file = $fscanf(w_file,"%s", captured_data);
        w_scan_file = $fscanf(w_file,"%s", captured_data);
        // This is for using weights of different tile (skips lines depending on which tile)
        for (j=0; j<tile*row; j=j+1) begin
            w_scan_file = $fscanf(w_file,"%64b", captured_data); 
        end
        
        // 1. Build the 32-bit weight vector by reading all 8 lines (Columns)
        // We use 'answer' as a temporary 32-bit accumulator
        temp_D_xmem = 0; 

       
        
        for (t=0; t<row; t=t+1) begin  

         
          // Read one line (representing one Output Channel Column)
          w_scan_file = $fscanf(w_file,"%64b", D_xmem); // 64 bits since we have 16x16 conv layer size now
          
          // Select the 4 bits corresponding to the current Input Channel (ic)
          // and place them into the correct slot of the accumulator.
          // t=0 (Col 0) -> Bits [3:0], t=7 (Col 7) -> Bits [31:28]

          // Syntax here:
            // data[0 +: 4] is the same as data[3:0].
            // data[8 +: 4] is the same as data[11:8].
            // data[t*4 +: 4] allows the starting bit to change based on variable t, 
            // but the width (4) must always be constant.
          // Indexed Part-Select [BASE +: WIDTH]
            // Rule: The BASE can be a variable (like t), but the WIDTH must be a constant.
          case(ic)
            0: temp_D_xmem[(t)*4 +: 4] = D_xmem[ 3: 0];
            1: temp_D_xmem[(t)*4 +: 4] = D_xmem[ 7: 4];
            2: temp_D_xmem[(t)*4 +: 4] = D_xmem[11: 8];
            3: temp_D_xmem[(t)*4 +: 4] = D_xmem[15:12];
            4: temp_D_xmem[(t)*4 +: 4] = D_xmem[19:16];
            5: temp_D_xmem[(t)*4 +: 4] = D_xmem[23:20];
            6: temp_D_xmem[(t)*4 +: 4] = D_xmem[27:24];
            7: temp_D_xmem[(t)*4 +: 4] = D_xmem[31:28];
            8: temp_D_xmem[(t)*4 +: 4] = D_xmem[35:32];
            9: temp_D_xmem[(t)*4 +: 4] = D_xmem[39:36];
            10: temp_D_xmem[(t)*4 +: 4] = D_xmem[43:40];
            11: temp_D_xmem[(t)*4 +: 4] = D_xmem[47:44];
            12: temp_D_xmem[(t)*4 +: 4] = D_xmem[51:48];
            13: temp_D_xmem[(t)*4 +: 4] = D_xmem[55:52];
            14: temp_D_xmem[(t)*4 +: 4] = D_xmem[59:56];
            15: temp_D_xmem[(t)*4 +: 4] = D_xmem[63:60];
          endcase
        end
        
        // 2. Write the constructed vector to memory
        D_xmem = temp_D_xmem[31:0];
        WEN_xmem = 0; 
        CEN_xmem = 0; 
        if (kij>0) A_xmem = A_xmem + 1; 
        // $display("A_xmem = %d, A_xmem_q = %d, kij = %d", A_xmem, A_xmem_q, kij);
        #0.5 clk = 1'b1;  


    
        $fclose(w_file);
      end //end of kij loop
        #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
        #0.5 clk = 1'b1; 


        /////////////////////////////////////
        // VISUAL VERIFICATION OF XMEM CONTENTS (Only Kij = 1)
        // -----------------------------------------------------------------------
        // Need one more clk cycle for the last write to show up vitually on SRAM 
        // #0.5 clk = 1'b0;   
        // #0.5 clk = 1'b1;   
        // #0.5 clk = 1'b0;   
        // #0.5 clk = 1'b1;  
        // $display("// -----------------------------------------------------------------------");
        // $display("// VISUAL VERIFICATION OF Kernel Loading to XMEM CONTENTS | %d", ic);
        // $display("// -----------------------------------------------------------------------");
        // $display("\nKernel weights (kij) loaded into XMEM (Addresses 1024 to %0d):", 1024+len_kij-1);
        // $display("Addr | Binary                           | Hex");
        // $display("-----|----------------------------------|---------");
        
        // for (i = 1024; i < (len_kij + 1024); i = i + 1) begin
        //     // NOTE: 'mem' must match the variable name of the reg array inside sram_32b_w2048.v
        //     // If it is named 'memory' or 'ram', change .mem[i] to .memory[i]
        //     $display("%4d | %b | %h \n", i, core_instance.xmem_inst.memory[i], core_instance.xmem_inst.memory[i]);
        // end
        // $display("----------------------------------------------------------\n");
        

      /////// Kernel data writing to IFIFO ///////
      // Need to send to memory 1 cycle earlier as it has 1 cycle higher wait
      #0.5 clk = 1'b0;   
      A_xmem = 1024; // Read from proper address, kij at 1024 to 1031
      WEN_xmem = 1;  
      CEN_xmem = 0;
      #0.5 clk = 1'b1;  

      // load kij times since there are kij weights to enter from north in output stationary
      for (t=0; t<len_kij; t=t+1)begin
        //Prepare SRAM to be read
        #0.5 clk = 1'b0;  
        WEN_xmem = 1;  
        CEN_xmem = 0;
        // Enable ififo write
        ififo_wr = 1; 
        ififo_rd = 0;

        A_xmem = A_xmem + 1; 
        #0.5 clk = 1'b1; 

      end
      
      #0.5 clk = 1'b0; WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
      ififo_wr = 0;
      #0.5 clk = 1'b1;
      /////////////////////////////////////

      // Need one more clk cycle for the last write to show up vitually on SRAM 
      #0.5 clk = 1'b0;   
      #0.5 clk = 1'b1;  



      // -----------------------------------------------------------------------
      // VISUAL VERIFICATION OF ififo FIFO CONTENTS
      // -----------------------------------------------------------------------
      // $display("// -----------------------------------------------------------------------");
      // $display("// VISUAL VERIFICATION OF IFIFO CONTENTS");
      // $display("// -----------------------------------------------------------------------");
      // $display("\n IFIFO Contents (First %0d words per col):", row);
      // $display("Col | Depth | Value (Hex)");
      // $display("----|-------|-------------");

      // `define PRINT_ififo_COL(COL_IDX) \
      //     $display(" %2d |   0  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q0); \
      //     $display(" %2d |   1  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q1); \
      //     $display(" %2d |   2  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q2); \
      //     $display(" %2d |   3  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q3); \
      //     $display(" %2d |   4  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q4); \
      //     $display(" %2d |   5  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q5); \
      //     $display(" %2d |   6  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q6); \
      //     $display(" %2d |   7  | %h", COL_IDX, core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.q7); \
      //     $display("----|-------|-------------");\
      //     $display(" Write_pointer | %b", core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.wr_ptr); \
      //     $display(" Read_pointer | %b", core_instance.corelet_instance.ififo_instance.col_num[COL_IDX].fifo_instance.rd_ptr); \
      //     $display("----|-------|-------------");\

      // // Manually call the macro for each row
      // `PRINT_ififo_COL(0)
      // `PRINT_ififo_COL(1)
      // `PRINT_ififo_COL(2)
      // `PRINT_ififo_COL(3)
      // `PRINT_ififo_COL(4)
      // `PRINT_ififo_COL(5)
      // `PRINT_ififo_COL(6)
      // `PRINT_ififo_COL(7)

      // `undef PRINT_ififo_COL // Clean up
      // $display("----------------------------------------------------------\n");
      // // -----------------------------------------------------------------------
      // #0.5 clk = 1'b0;   
      // #0.5 clk = 1'b1; 


      /////// Activation data writing to L0 ///////
      // Need to send to memory 1 cycle earlier as it has 1 cycle higher wait
      #0.5 clk = 1'b0;   
      A_xmem = 0; // Read from proper address, starting from 0 for activation
      WEN_xmem = 1;  
      CEN_xmem = 0;
      #0.5 clk = 1'b1;  

      for (t=0; t<len_kij; t=t+1)begin
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
      // $display("Rd_ptr = %d, Wr_ptr = %d", core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.rd_ptr, core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.wr_ptr); \
      // $display(" %2d |  0  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q0)); \
      // $display(" %2d |  1  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q1)); \
      // $display(" %2d |  2  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q2)); \
      // $display(" %2d |  3  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q3)); \
      // $display(" %2d |  4  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q4)); \
      // $display(" %2d |  5  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q5)); \
      // $display(" %2d |  6  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q6)); \
      // $display(" %2d |  7  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q7)); \
      // $display(" %2d |  8  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q8)); \
      // $display(" %2d |  9  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q9)); \
      // $display(" %2d | 10  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q10)); \
      // $display(" %2d | 11  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q11)); \
      // $display(" %2d | 12  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q12)); \
      // $display(" %2d | 13  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q13)); \
      // $display(" %2d | 14  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q14)); \
      // $display(" %2d | 15  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q15)); \
      // $display(" %2d | 16  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q16)); \
      // $display(" %2d | 17  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q17)); \
      // $display(" %2d | 18  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q18)); \
      // $display(" %2d | 19  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q19)); \
      // $display(" %2d | 20  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q20)); \
      // $display(" %2d | 21  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q21)); \
      // $display(" %2d | 22  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q22)); \
      // $display(" %2d | 23  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q23)); \
      // $display(" %2d | 24  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q24)); \
      // $display(" %2d | 25  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q25)); \
      // $display(" %2d | 26  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q26)); \
      // $display(" %2d | 27  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q27)); \
      // $display(" %2d | 28  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q28)); \
      // $display(" %2d | 29  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q29)); \
      // $display(" %2d | 30  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q30)); \
      // $display(" %2d | 31  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q31)); \
      // $display(" %2d | 32  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q32)); \
      // $display(" %2d | 33  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q33)); \
      // $display(" %2d | 34  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q34)); \
      // $display(" %2d | 35  | %d", ROW_IDX, $signed(core_instance.corelet_instance.l0_instance.row_num[ROW_IDX].fifo_instance.q35)); \

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
      // -----------------------------------------------------------------------
      #0.5 clk = 1'b0;   
      #0.5 clk = 1'b1; 
      /////////////////////////////////////



      /////// Execution ///////
      
      // takes len_kij cycles to send everything from first fifo
      // at which point we turn off fifo 1 by 1
      // then it takes row number of cycles to turn off last fifo
      // it then takes row number of cycles to pass last value to last PE
      for (t=0; t<len_kij+row*2 + 2; t=t+1) begin  
        #0.5 clk = 1'b0;   

        // Only need to send inst_w once, as it gets passed
        
        // After kij number of cycles, first fifo in l0 would have to stop
        // so we need to shut it down. The shut down signal propapages to the next
        // fifo columns in l0 automatically cycle by cycle (check l0 code)
        if (t < len_kij) begin
          l0_rd = 1; // send from l0
          ififo_rd = 1; // send from ififo too for output stationary
          load = 0;
          execute = 1;
        end
        else begin
          l0_rd = 0;
          ififo_rd = 0;
          load = 0;
          execute = 0;
        end
        #0.5 clk = 1'b1;  

      // Helper Macros for Visualization of Array
      `define TILE(R, C) core_instance.corelet_instance.mac_array_instance.row_num[R].mac_row_instance.col_num[C].mac_tile_instance
      
      // Format: Weight | ActLo ActHi | PsumLo PsumHi
      `define PRINT_MAC_ROW(R) \
      $display("R%0d | %2d %2d %2d %3d %3d | %2d %2d %2d %3d %3d | %2d %2d %2d %3d %3d | %2d %2d %2d %3d %3d | %2d %2d %2d %3d %3d | %2d %2d %2d %3d %3d | %2d %2d %2d %3d %3d | %2d %2d %2d %3d %3d |", R, \
        $signed(`TILE(R,1).b_q), `TILE(R,1).alo_q, `TILE(R,1).ahi_q, $signed(`TILE(R,1).c_q), $signed(`TILE(R,1).c_q2), \
        $signed(`TILE(R,2).b_q), `TILE(R,2).alo_q, `TILE(R,2).ahi_q, $signed(`TILE(R,2).c_q), $signed(`TILE(R,2).c_q2), \
        $signed(`TILE(R,3).b_q), `TILE(R,3).alo_q, `TILE(R,3).ahi_q, $signed(`TILE(R,3).c_q), $signed(`TILE(R,3).c_q2), \
        $signed(`TILE(R,4).b_q), `TILE(R,4).alo_q, `TILE(R,4).ahi_q, $signed(`TILE(R,4).c_q), $signed(`TILE(R,4).c_q2), \
        $signed(`TILE(R,5).b_q), `TILE(R,5).alo_q, `TILE(R,5).ahi_q, $signed(`TILE(R,5).c_q), $signed(`TILE(R,5).c_q2), \
        $signed(`TILE(R,6).b_q), `TILE(R,6).alo_q, `TILE(R,6).ahi_q, $signed(`TILE(R,6).c_q), $signed(`TILE(R,6).c_q2), \
        $signed(`TILE(R,7).b_q), `TILE(R,7).alo_q, `TILE(R,7).ahi_q, $signed(`TILE(R,7).c_q), $signed(`TILE(R,7).c_q2), \
        $signed(`TILE(R,8).b_q), `TILE(R,8).alo_q, `TILE(R,8).ahi_q, $signed(`TILE(R,8).c_q), $signed(`TILE(R,8).c_q2));

        // --- VISUALIZATION BLOCK ---
        if (tile > 0) begin
        // $display("\nCycle %0d: MAC Array State [Weight Act(Lo Hi) Psum(Lo Hi)]", t);
        // $display("   | C0                | C1                | C2                | C3                | C4                | C5                | C6                | C7                |");
        // $display("---|-------------------|-------------------|-------------------|-------------------|-------------------|-------------------|-------------------|-------------------|");
        // `PRINT_MAC_ROW(1)
        // `PRINT_MAC_ROW(2)
        // `PRINT_MAC_ROW(3)
        // `PRINT_MAC_ROW(4)
        // `PRINT_MAC_ROW(5)
        // `PRINT_MAC_ROW(6)
        // `PRINT_MAC_ROW(7)
        // `PRINT_MAC_ROW(8)

        // $display("------------------------------------------------------------------------------------------------------------------");
      end
      end


    end  // end of ic loop (end of acumulation in mac)


    /// Send accumulated values from MAC array to OFIFO ///
      // OFIFO has 64 depth, each of them is enough to store all
      // Output depth for output stationary should be number of output_nij locations
      // Here we only have 8 mapped (room for future improvement and tiling implementation)

    for (t=0; t<16 + 2; t=t+1) begin  // set to 16 since we are mapping all 16 output_nij. +2 for the delay from testbench to ofifo valid to array
      #0.5 clk = 1'b0;  
      // Tell array outputs are ready to be passed out
      os_out = 1;
      // ofifo write enabled by os_out too (see mac_row.v line 33)
    //   // Helper Macros for Visualization of Array
    // `define TILE(R, C) core_instance.corelet_instance.mac_array_instance.row_num[R].mac_row_instance.col_num[C].mac_tile_instance
    
    // `define PRINT_MAC_ROW(R) \
    // $display("Row %0d | %4d %4d %4d | %4d %4d %4d | %4d %4d %4d | %4d %4d %4d | %4d %4d %4d | %4d %4d %4d | %4d %4d %4d | %4d %4d %4d |", R, \
    //    $signed(`TILE(R,1).b_q), $signed(`TILE(R,1).a_q), $signed(`TILE(R,1).c_q), \
    //    $signed(`TILE(R,2).b_q), $signed(`TILE(R,2).a_q), $signed(`TILE(R,2).c_q), \
    //    $signed(`TILE(R,3).b_q), $signed(`TILE(R,3).a_q), $signed(`TILE(R,3).c_q), \
    //    $signed(`TILE(R,4).b_q), $signed(`TILE(R,4).a_q), $signed(`TILE(R,4).c_q), \
    //    $signed(`TILE(R,5).b_q), $signed(`TILE(R,5).a_q), $signed(`TILE(R,5).c_q), \
    //    $signed(`TILE(R,6).b_q), $signed(`TILE(R,6).a_q), $signed(`TILE(R,6).c_q), \
    //    $signed(`TILE(R,7).b_q), $signed(`TILE(R,7).a_q), $signed(`TILE(R,7).c_q), \
    //    $signed(`TILE(R,8).b_q), $signed(`TILE(R,8).a_q), $signed(`TILE(R,8).c_q));

    //   // --- VISUALIZATION BLOCK ---
    //   $display("\nCycle %0d: MAC Array State [Weight Activation Psum]", t);
    //   $display("   | C0          | C1          | C2          | C3          | C4          | C5          | C6          | C7          |");
    //   $display("---|-------------|-------------|-------------|-------------|-------------|-------------|-------------|-------------|");
    //   `PRINT_MAC_ROW(1)
    //   `PRINT_MAC_ROW(2)
    //   `PRINT_MAC_ROW(3)
    //   `PRINT_MAC_ROW(4)
    //   `PRINT_MAC_ROW(5)
    //   `PRINT_MAC_ROW(6)
    //   `PRINT_MAC_ROW(7)
    //   `PRINT_MAC_ROW(8)

    //   $display("------------------------------------------------------------------------------------------------------------------");
    //   $display("Valid bits of last row: %b", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.valid_q);
      #0.5 clk = 1'b1;   
    end
   
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    os_out = 0;



    
    

    // -----------------------------------------------------------------------
    // VISUAL VERIFICATION OF L0 FIFO CONTENTS
    // -----------------------------------------------------------------------
    // $display("// -----------------------------------------------------------------------");
    // $display("// VISUAL VERIFICATION OF OFIFO CONTENTS");
    // $display("// -----------------------------------------------------------------------");
    // $display("\n OFIFO Contents (First %0d words per row):", col);
    // $display("Row | Depth | Value");
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
    // /////////////////////////////////////



    //////// OFIFO READ ////////
    // Ideally, OFIFO should be read while execution, but we have enough ofifo
    // depth so we can fetch out after execution.

    // A_pmem is set to 0 at the very start (before kij loop), so 
    // resetting it here would just result in overwriting
    A_pmem = tile*len_onij;

    #0.5 clk = 1'b0;  
    // Need this line so that the timing of memory write and ofifo read is right
    ofifo_rd = 1; 
    #0.5 clk = 1'b1;   

    for (t=0; t<16; t=t+1) begin  // set to 16 since we are only mapping 16 output_nij
      #0.5 clk = 1'b0;  
      // ofifo read enable
      ofifo_rd = 1;
      // Write signals to pmem
      WEN_pmem = 0; 
      CEN_pmem = 0; 
      if (t>0) A_pmem = A_pmem + 1;
      #0.5 clk = 1'b1;   
    end

    #0.5 clk = 1'b0;  
    WEN_pmem = 1;  CEN_pmem = 1; ofifo_rd = 0; 
    // This makes sure we write to the next address instead of overwriting the end of this kij
    A_pmem = A_pmem + 1;

    #0.5 clk = 1'b1; 

    /////////////////////////////////////////////////
    // -----------------------------------------------------------------------

   
    // VISUAL VERIFICATION OF PMEM CONTENTS
    // -----------------------------------------------------------------------
    // Need one more clk cycle for the last write to show up vitually on SRAM 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
    $display("// -----------------------------------------------------------------------");
    $display("// VISUAL VERIFICATION OF OFIFO Loading to PMEM ");
    $display("// -----------------------------------------------------------------------");
    $display("\ OFIFO data loaded into PMEM (Addresses 0 to %0d):", len_nij-1);
    $display("Addr | Bank0 Lower16 | Bank0 Upper16 | Bank1 Lower16 | Bank1 Upper16 | Bank2 Lower16 | Bank2 Upper16 | Bank3 Lower16 | Bank3 Upper16 ");
    $display("-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------");

   

    for (i = 0; i < 32; i = i + 1) begin
        ind = i;
        // Read 32-bit words from each bank
        bank0_word = core_instance.pmem_row[0].pmem_instance.memory[ind];
        bank1_word = core_instance.pmem_row[1].pmem_instance.memory[ind];
        bank2_word = core_instance.pmem_row[2].pmem_instance.memory[ind];
        bank3_word = core_instance.pmem_row[3].pmem_instance.memory[ind];
        
        // Split each 32-bit word into signed 16-bit halves
        bank0_lower = $signed(bank0_word[15:0]);
        bank0_upper = $signed(bank0_word[31:16]);
        bank1_lower = $signed(bank1_word[15:0]);
        bank1_upper = $signed(bank1_word[31:16]);
        bank2_lower = $signed(bank2_word[15:0]);
        bank2_upper = $signed(bank2_word[31:16]);
        bank3_lower = $signed(bank3_word[15:0]);
        bank3_upper = $signed(bank3_word[31:16]);
        
        $display("%4d | %d        | %d        | %d        | %d        | %d        | %d        | %d        | %d       \n",
                ind,
                bank0_lower, 
                bank0_upper, 
                bank1_lower, 
                bank1_upper, 
                bank2_lower, 
                bank2_upper, 
                bank3_lower, 
                bank3_upper);
        $display("A_pmem: %d", A_pmem_q);
    end
    $display("----------------------------------------------------------------------------------------------------------------------------");

    /////////////////////////////////////


    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1; 


   
  
    // The lines of output are stored in PMEM upside down
    // Since we read from the bottom of the MAC array first. 
    // The first row is at the last address, which is 15, since 
    // we mapped 16 o_nij
    A_pmem = 15+(tile*16);
    #0.5 clk = 1'b0; 
    #0.5 clk = 1'b1;
    for (i=0; i<16; i=i+1) begin // len_onij is 8 since we only mapped 8 for o_stationary

      
    

      // wait some clk cycles before memory -> sfu -> sfu_out
      
      #0.5 clk = 1'b0; 
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0; 
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0; 
      #0.5 clk = 1'b1;
      
      temp_answer[i][128*tile +: 128] = sfp_out;
      
      

      relu = 0;
      #0.5 clk = 1'b0; reset = 1;
      #0.5 clk = 1'b1;  
      #0.5 clk = 1'b0; reset = 0; 
      #0.5 clk = 1'b1;  


      
      #0.5 clk = 1'b0;   
      CEN_pmem = 0; WEN_pmem = 1; // read from pmem
      if(i>0) A_pmem = A_pmem - 1;

      #0.5 clk = 1'b1;   

    end
  end // End of tile loop

  
  ////////// Output Stationary Verification /////////
  out_file = $fopen("text_files/2bit/out.txt", "r");  


  // Following three lines are to remove the first three comment lines of the file
  out_scan_file = $fscanf(out_file,"%s", captured_data); 
  out_scan_file = $fscanf(out_file,"%s", captured_data); 
  out_scan_file = $fscanf(out_file,"%s", captured_data); 

  error = 0;



  $display("############ Verification Start during accumulation #############"); 
 
  for (i=0; i<16; i=i+1) begin 
    if (i>0) begin
     out_scan_file = $fscanf(out_file,"%256b", answer); // reading from out file to answer
       if (temp_answer[i] == answer)
         $display("%2d-th output featuremap Data matched! :D", i); 
       else begin
         $display("%2d-th output featuremap Data ERROR!!", i); 
         $display("my_output: %128b, %d", temp_answer[i], $signed(temp_answer[i][15:0]));
         $display("answer: %128b, %d", answer, $signed(answer[15:0]));

         error = 1;
       end
    end
   
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
    // CEN_pmem = 1; WEN_pmem = 1; 
    
   

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




