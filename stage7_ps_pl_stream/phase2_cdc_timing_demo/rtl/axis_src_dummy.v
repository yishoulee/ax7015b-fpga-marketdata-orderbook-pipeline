module axis_src_dummy #(
  parameter integer TDATA_BITS = 32
)(
  input  wire                   aclk,
  input  wire                   aresetn,

  output reg  [TDATA_BITS-1:0]  m_axis_tdata,
  output reg                    m_axis_tvalid,
  input  wire                   m_axis_tready
);

  always @(posedge aclk) begin
    if (!aresetn) begin
      m_axis_tdata  <= {TDATA_BITS{1'b0}};
      m_axis_tvalid <= 1'b0;
    end else begin
      m_axis_tvalid <= 1'b1;
      if (m_axis_tvalid && m_axis_tready) begin
        m_axis_tdata <= m_axis_tdata + 1'b1;
      end
    end
  end

endmodule
