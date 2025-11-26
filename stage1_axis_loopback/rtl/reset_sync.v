`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2025 02:36:09 PM
// Design Name: 
// Module Name: reset_sync
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


// reset_sync.v : synchronous, active-low reset from a level input
module reset_sync #(parameter N=2)(
  input  wire clk,
  input  wire rst_level,   // 1 = request reset
  output wire rstn_out     // active-low to fabric
);
  reg [N-1:0] sh = {N{1'b1}};
  always @(posedge clk) begin
    if (rst_level) sh <= {N{1'b0}};          // assert low immediately
    else           sh <= {sh[N-2:0], 1'b1};  // deassert after N cycles
  end
  assign rstn_out = sh[N-1];
endmodule
