module mac_array (clk, reset, out_s, in_w, in_n, inst_w, two_bit_mode, load_b2, os_out, mode_sel, valid);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; 
  input  [1:0] inst_w;// inst[1]:execute, inst[0]: kernel loading
  input  [bw*col-1:0] in_n;
  input  two_bit_mode; // for SIMD
  input  load_b2;
  input mode_sel;
  input os_out; // for output stationary (see mac_tile for detials)
  output [col-1:0] valid;

  // Need to pad and sign-extend the in_n from fifo
  wire [psum_bw*col-1:0] in_n_ext_flat;
  genvar k;
  generate
      for (k = 0; k < 8; k = k + 1) begin : sign_extend_flat
          assign in_n_ext_flat[(k+1)*psum_bw-1:k*psum_bw] = { {12{in_n[(k+1)*bw-1]}}, in_n[(k+1)*bw-1:k*bw] };
      end
  endgenerate

  wire [(row+1)*psum_bw*col-1:0] temp_psum; // row + 1 because after last row we still need to store partial sum
  wire [(row+1)*psum_bw*col-1:0] temp_psum2; // row + 1 because after last row we still need to store partial sum
  reg [1:0] temp_inst_w [0:row-1];// no row + 1 here because we don't need instruction after last row
  wire [row*col-1:0] valid_q;

  assign out_s = temp_psum[psum_bw*col*9-1:psum_bw*col*8]; // use 9 here since last psum is after all 8 rows
  assign temp_psum[psum_bw*col-1:0] = (mode_sel) ? in_n_ext_flat : 0; // psum should be 0 at the very start before adding anything or in_n for output stationary
  assign valid = valid_q[row*col-1:row*col-8];

  integer j;
  always @ (posedge clk) begin
    if(reset)begin
      for (j = 0; j < row; j=j+1)begin
        temp_inst_w[j] <= 0;
      end
    end
    // inst_w flows from row0 to row7
    temp_inst_w[0] <= inst_w;

    for (j = 1; j < row; j=j+1) begin
      temp_inst_w[j] <= temp_inst_w[j-1];
    end
  end

  genvar i;
  generate
  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
      .clk(clk),
      .reset(reset),
      .two_bit_mode(two_bit_mode),
      .load_b2(load_b2),
      .mode_sel(mode_sel),
      .os_out(os_out),
      .in_w(in_w[i*bw-1:(i-1)*bw]),
      .inst_w(temp_inst_w[i-1]),
      .in_n(temp_psum[i*col*psum_bw-1:(i-1)*psum_bw*col]),
          .out_s(temp_psum[(i+1)*col*psum_bw-1:i*psum_bw*col]),
          .valid(valid_q[i*col-1:col*(i-1)])
      
      );
  end
  endgenerate

  


endmodule
