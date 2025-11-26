`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/23/2025 09:26:14 AM
// Design Name: 
// Module Name: axis_sink
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
module axis_sink #
(
  parameter integer W = 32
)(
  input  wire             clk,
  input  wire             aresetn,         // active-low sync reset

  // S_AXIS (from FIFO M_AXIS)
  input  wire [W-1:0]     s_axis_tdata,
  input  wire             s_axis_tvalid,
  output wire             s_axis_tready,
  input  wire             s_axis_tlast,

  // Status/observability
  output reg  [31:0]      word_count,      // counts words in current frame
  output reg  [31:0]      frame_count,     // #frames seen
  output reg              last_seen        // pulses 1 cycle at TLAST handshake
);
  assign s_axis_tready = 1'b1; // always ready consumer (good for bring-up)

  always @(posedge clk) begin
    if (!aresetn) begin
      word_count <= 32'd0;
      frame_count <= 32'd0;
      last_seen <= 1'b0;
    end else begin
      last_seen <= 1'b0;
      if (s_axis_tvalid && s_axis_tready) begin
        word_count <= word_count + 1;
        if (s_axis_tlast) begin
          frame_count <= frame_count + 1;
          last_seen <= 1'b1;
          word_count <= 32'd0; // reset for next frame
        end
      end
    end
  end
endmodule
