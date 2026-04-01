
module ofifo (clk, in, out, rd, wr, o_full, reset, o_ready, o_valid);

  parameter col  = 8;
  parameter bw = 4;
  parameter psum_bw = 16;

  input  clk;
  input  [col-1:0] wr;
  input  rd;
  input  reset;
  input  [psum_bw*col-1:0] in;
  output [psum_bw*col-1:0] out; // might have to change width as psum is wide
  output o_full;
  output o_ready;
  output o_valid;

  wire [col-1:0] empty;
  wire [col-1:0] full;
  reg  rd_en;
 
  assign o_ready = ~|full ;
  assign o_full  = |full ;
  assign o_valid = ~empty[col-1] ; //when last FIFO gets its first value

  genvar i;
  generate
  for (i=0; i<col ; i=i+1) begin : col_num
      fifo_depth64 #(.bw(psum_bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
	 .rd(rd_en), // only 1 bit needed for rd_en since we always read out 1 whole line at a time
	 .wr(wr[i]),
         .o_empty(empty[i]),
         .o_full(full[i]),
	 .in(in[psum_bw*(i+1)-1:psum_bw*i]),
	 .out(out[psum_bw*(i+1)-1:psum_bw*i]),
         .reset(reset));
  end
  endgenerate

  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 0;
   end
   else
      if (rd) begin
        rd_en <= 1;
      end
  end


 

endmodule
