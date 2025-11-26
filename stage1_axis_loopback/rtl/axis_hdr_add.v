`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2025 02:22:00 PM
// Design Name: 
// Module Name: axis_hdr_add
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
module axis_hdr_add #
(
  parameter DATA_WIDTH = 32
)(
  input  wire                   clk,
  input  wire                   rstn,          // active-low sync reset

  // S_AXIS
  input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
  input  wire                   s_axis_tvalid,
  output wire                   s_axis_tready,
  input  wire                   s_axis_tlast,

  // M_AXIS
  output reg  [DATA_WIDTH-1:0]  m_axis_tdata,
  output reg                    m_axis_tvalid,
  input  wire                   m_axis_tready,
  output reg                    m_axis_tlast
);

  // States
  localparam S_HDR  = 1'b0;  // inject header for new frame
  localparam S_PASS = 1'b1;  // pass payload
  reg state;

  // Hold the first payload while sending header
  reg [DATA_WIDTH-1:0] hold_data;
  reg                  hold_last;
  reg                  have_hold;

  // Output can load when empty or just consumed
  wire load_out = (~m_axis_tvalid) | m_axis_tready;

  // READY policy:
  //  - S_HDR: accept exactly one first payload beat.
  //  - S_PASS: if we're still holding the first beat, CLOSE ready (avoid dropping next beat);
  //            otherwise use classic reg-slice rule.
  assign s_axis_tready =
      (state == S_HDR) ? (~have_hold) :
      ((have_hold) ? 1'b0 : (m_axis_tready | ~m_axis_tvalid));

  always @(posedge clk) begin
    if (!rstn) begin
      state         <= S_HDR;
      have_hold     <= 1'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tlast  <= 1'b0;
      m_axis_tdata  <= {DATA_WIDTH{1'b0}};
    end else begin
      // Drop valid after consumption
      if (m_axis_tvalid & m_axis_tready)
        m_axis_tvalid <= 1'b0;

      // Capture first payload while in S_HDR (one beat only)
      if ((state == S_HDR) & s_axis_tvalid & s_axis_tready) begin
        hold_data <= s_axis_tdata;
        hold_last <= s_axis_tlast;
        have_hold <= 1'b1;
      end

      if (state == S_HDR) begin
        // Emit header only after first payload is captured and output is free
        if (have_hold & load_out) begin
          m_axis_tdata  <= 32'hDEADBEEF;
          m_axis_tlast  <= 1'b0;    // header is never last
          m_axis_tvalid <= 1'b1;
          state         <= S_PASS;  // next: send held payload
        end
      end else begin // S_PASS
        // While holding first payload, send it first and keep input closed
        if (have_hold & load_out) begin
          m_axis_tdata  <= hold_data;
          m_axis_tlast  <= hold_last;
          m_axis_tvalid <= 1'b1;
          have_hold     <= 1'b0;
        end
        // After held beat is sent, normal pass-through
        if (!have_hold & s_axis_tvalid & (m_axis_tready | ~m_axis_tvalid)) begin
          m_axis_tdata  <= s_axis_tdata;
          m_axis_tlast  <= s_axis_tlast;
          m_axis_tvalid <= 1'b1;
        end
        // End of frame -> back to S_HDR after last beat handshake
        if (m_axis_tvalid & m_axis_tready & m_axis_tlast)
          state <= S_HDR;
      end
    end
  end
endmodule
