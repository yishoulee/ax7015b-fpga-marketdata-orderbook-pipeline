`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2025 02:10:14 PM
// Design Name: 
// Module Name: axis_test_src
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
module axis_test_src #
(
  parameter integer W           = 32,
  parameter integer N_WORDS     = 32,              // payload beats per frame
  parameter [W-1:0] BASE        = 32'h11110000,    // payload base pattern
  parameter integer AUTO_REARM  = 0,               // 1 = keep sending frames
  parameter integer INTER_GAP   = 64               // idle cycles between frames when AUTO_REARM=1
)(
  input  wire             clk,
  input  wire             aresetn,      // active-low sync reset
  input  wire             start,        // 1-cycle pulse to (re)arm when AUTO_REARM=0
  output reg  [W-1:0]     m_axis_tdata,
  output reg              m_axis_tvalid,
  input  wire             m_axis_tready,
  output reg              m_axis_tlast
);

  // clog2 in plain Verilog
  function integer CLOG2;
    input integer value; integer i;
    begin
      value = value-1; for (i=0; value>0; i=i+1) value = value>>1;
      CLOG2 = (i==0)?1:i;
    end
  endfunction

  localparam IDX_W = (N_WORDS<=1) ? 1 : CLOG2(N_WORDS);
  localparam ST_IDLE = 2'd0, ST_SEND = 2'd1, ST_GAP = 2'd2;

  reg [1:0]          st;
  reg [IDX_W-1:0]    idx;
  reg [CLOG2(INTER_GAP)-1:0] gap_cnt;

  wire advance = m_axis_tvalid & m_axis_tready;

  always @(posedge clk) begin
    if (!aresetn) begin
      st <= ST_IDLE;
      idx <= {IDX_W{1'b0}};
      gap_cnt <= {CLOG2(INTER_GAP){1'b0}};
      m_axis_tvalid <= 1'b0;
      m_axis_tlast  <= 1'b0;
      m_axis_tdata  <= {W{1'b0}};
    end else begin
      case (st)
        ST_IDLE: begin
          m_axis_tvalid <= 1'b0;
          m_axis_tlast  <= 1'b0;
          idx <= {IDX_W{1'b0}};
          if ((AUTO_REARM!=0) || start) begin
            // present first payload word
            m_axis_tdata  <= BASE;
            m_axis_tlast  <= (N_WORDS==1);
            m_axis_tvalid <= 1'b1;
            st <= ST_SEND;
          end
        end

        ST_SEND: begin
          if (advance) begin
            if (idx == N_WORDS-1) begin
              // last beat just transferred
              m_axis_tvalid <= 1'b0;
              m_axis_tlast  <= 1'b0;
              idx <= {IDX_W{1'b0}};
              if (AUTO_REARM!=0) begin
                gap_cnt <= {CLOG2(INTER_GAP){1'b0}};
                st <= ST_GAP;
              end else begin
                st <= ST_IDLE;
              end
            end else begin
              idx <= idx + {{(IDX_W-1){1'b0}},1'b1};
              m_axis_tdata <= BASE + (idx + {{(IDX_W-1){1'b0}},1'b1});
              m_axis_tlast <= ((idx + {{(IDX_W-1){1'b0}},1'b1}) == (N_WORDS-1));
              m_axis_tvalid <= 1'b1; // hold valid with new data
            end
          end
        end

        ST_GAP: begin
          // idle for INTER_GAP cycles, then start next frame
          m_axis_tvalid <= 1'b0;
          m_axis_tlast  <= 1'b0;
          if (gap_cnt == INTER_GAP-1) begin
            // start next frame
            m_axis_tdata  <= BASE;
            m_axis_tlast  <= (N_WORDS==1);
            m_axis_tvalid <= 1'b1;
            st <= ST_SEND;
            gap_cnt <= {CLOG2(INTER_GAP){1'b0}};
          end else begin
            gap_cnt <= gap_cnt + {{(CLOG2(INTER_GAP)-1){1'b0}},1'b1};
          end
        end

        default: st <= ST_IDLE;
      endcase
    end
  end
endmodule

