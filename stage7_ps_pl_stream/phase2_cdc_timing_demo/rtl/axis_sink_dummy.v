module axis_sink_dummy #(
  parameter integer TDATA_BITS = 32
)(
  input  wire                   aclk,
  input  wire                   aresetn,

  input  wire [TDATA_BITS-1:0]  s_axis_tdata,
  input  wire                   s_axis_tvalid,
  output reg                    s_axis_tready,

  output reg                    led_out
);

  reg [31:0] beat_count;

  always @(posedge aclk) begin
    if (!aresetn) begin
      s_axis_tready <= 1'b0;
      beat_count    <= 32'd0;
      led_out       <= 1'b0;
    end else begin
      s_axis_tready <= 1'b1;
      if (s_axis_tvalid && s_axis_tready) begin
        beat_count <= beat_count + 1'b1;
      end
      led_out <= beat_count[24];
    end
  end

endmodule
