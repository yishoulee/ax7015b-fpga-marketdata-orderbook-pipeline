`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2025 02:23:44 PM
// Design Name: 
// Module Name: edge_pulse
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
module edge_pulse #
(
  parameter N_SYNC = 2
)(
  input  wire clk,
  input  wire rstn,       // active-low sync reset
  input  wire level_in,   // VIO bit
  output wire pulse_out   // 1 clk-wide pulse on 0->1
);
  reg [N_SYNC:0] sh;

  always @(posedge clk) begin
    if (!rstn)
      sh <= { (N_SYNC+1){1'b0} }; // explicit sizing
    else
      sh <= { sh[N_SYNC-1:0], level_in };
  end

  assign pulse_out = sh[N_SYNC] & ~sh[N_SYNC-1];
endmodule
