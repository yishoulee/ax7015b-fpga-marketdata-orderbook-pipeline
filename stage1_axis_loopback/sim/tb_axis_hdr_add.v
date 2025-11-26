`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/22/2025 11:17:38 AM
// Design Name: 
// Module Name: tb_axis_hdr_add
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
module tb_axis_hdr_add;

  // 100 MHz clock
  reg clk = 0;
  always #10 clk = ~clk;

  // active-low reset
  reg rstn = 0;

  // start pulse (generated locally: 1 cycle)
  reg start_pulse = 0;

  // Wires between source and adder
  wire [31:0] s_tdata, m_tdata;
  wire        s_tvalid, s_tready, s_tlast;
  wire        m_tvalid, m_tready, m_tlast;

  // DUTs
  axis_test_src #(.W(32)) u_src (
  .clk(clk),
  .aresetn(rstn),          // tie your tb's rstn to aresetn
  .start(start_pulse),     // feed 1-cycle pulse here
  .m_axis_tdata(s_tdata),
  .m_axis_tvalid(s_tvalid),
  .m_axis_tready(s_tready),
  .m_axis_tlast(s_tlast)
  );


  axis_hdr_add #(.DATA_WIDTH(32)) u_hdr (
    .clk(clk), .rstn(rstn),
    .s_axis_tdata(s_tdata), .s_axis_tvalid(s_tvalid),
    .s_axis_tready(s_tready), .s_axis_tlast(s_tlast),
    .m_axis_tdata(m_tdata), .m_axis_tvalid(m_tvalid),
    .m_axis_tready(m_tready), .m_axis_tlast(m_tlast)
  );

  // Dummy sink keeps READY high
  assign m_tready = 1'b1;

  // Stimulus
  initial begin
    // Global Set/Reset settles - wait a little before starting (Vivado sim recommendation)
    rstn = 0;
    repeat (20) @(posedge clk);   // ~200 ns
    rstn = 1;
    repeat (10) @(posedge clk);

    // fire one frame (1-cycle pulse)
    start_pulse = 1; @(posedge clk); start_pulse = 0;

    // wait for TLAST transfer, then another frame
    wait(m_tvalid && m_tready && m_tlast);
    repeat (10) @(posedge clk);
    start_pulse = 1; @(posedge clk); start_pulse = 0;

    repeat (50) @(posedge clk);
    $finish;
  end

  // Simple monitor: log each transferred beat
  initial begin
    $display("time\tTVALID TREADY TLAST TDATA");
    forever begin
      @(posedge clk);
      if (m_tvalid && m_tready)
        $display("%0t\t%b      %b      %b    0x%08h",
          $time, m_tvalid, m_tready, m_tlast, m_tdata);
    end
  end
  
endmodule

