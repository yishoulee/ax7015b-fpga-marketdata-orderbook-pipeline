//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/23/2025 11:05:42 AM
// Design Name: 
// Module Name: bram_axis_src
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
module bram_axis_src #(
  parameter integer W           = 32,    // TDATA width (must match BRAM data width)
  parameter integer N_WORDS     = 1024,  // number of payload words per frame
  parameter integer AUTO_REARM  = 0,     // 1 = keep sending frames
  parameter integer GAP_CYC     = 32     // idle cycles between frames when AUTO_REARM=1
)(
  // Clock/reset/control
  input  wire             clk,
  input  wire             aresetn,       // active-low synchronous reset
  input  wire             start,         // 1-cycle pulse when AUTO_REARM=0

  // BRAM native read port (we read-only from this port)
  // NOTE: Width declared wide enough; synthesis will truncate to BRAM's addra width.
//  output reg  [31:0]      bram_addr,
  output reg [9:0]        bram_addr, 
  output wire             bram_en,
  input  wire [W-1:0]     bram_dout,

  // AXI-Stream master
  output reg  [W-1:0]     m_axis_tdata,
  output reg              m_axis_tvalid,
  input  wire             m_axis_tready,
  output reg              m_axis_tlast
);

  // -----------------------------
  // Utilities / local parameters
  // -----------------------------
  // ceil(log2(v))
  function integer CLOG2;
    input integer value;
    integer i;
    begin
      value = value - 1;
      for (i = 0; value > 0; i = i + 1)
        value = value >> 1;
      CLOG2 = (i == 0) ? 1 : i;
    end
  endfunction

  localparam integer ADDR_W = (N_WORDS <= 1) ? 1 : CLOG2(N_WORDS);
  localparam integer GAP_W  = (GAP_CYC  <= 1) ? 1 : CLOG2(GAP_CYC);

  // -----------------------------
  // State / registers
  // -----------------------------
  localparam [1:0] ST_IDLE  = 2'd0,
                   ST_PRIME = 2'd1,   // issue addra=0, wait one cycle, present first word
                   ST_SEND  = 2'd2,   // stream words with proper handshakes
                   ST_GAP   = 2'd3;

  reg [1:0]              st;
  reg [ADDR_W-1:0]       rd_idx;       // how many words already presented
  reg [GAP_W-1:0]        gap_cnt;

  wire advance = m_axis_tvalid & m_axis_tready;   // AXIS handshake
  assign bram_en = 1'b1;                          // BRAM permanently enabled while active

  // -----------------------------
  // Main FSM
  // -----------------------------
  always @(posedge clk) begin
    if (!aresetn) begin
      st            <= ST_IDLE;
      rd_idx        <= {ADDR_W{1'b0}};
      gap_cnt       <= {GAP_W{1'b0}};
      bram_addr     <= 32'd0;
      m_axis_tvalid <= 1'b0;
      m_axis_tlast  <= 1'b0;
      m_axis_tdata  <= {W{1'b0}};
    end
    else begin
      case (st)
        // -------------------------
        ST_IDLE: begin
          m_axis_tvalid <= 1'b0;
          m_axis_tlast  <= 1'b0;
          rd_idx        <= {ADDR_W{1'b0}};
          bram_addr     <= 32'd0;

          if ((AUTO_REARM != 0) || start) begin
            // Put address 0 on BRAM; data will be valid next cycle
            bram_addr <= 32'd0;
            st        <= ST_PRIME;
          end
        end

        // -------------------------
        ST_PRIME: begin
          // First data becomes available from BRAM after previous cycle's addra
          m_axis_tdata  <= bram_dout;
          m_axis_tlast  <= (N_WORDS == 1);
          m_axis_tvalid <= 1'b1;

          rd_idx    <= (N_WORDS == 1) ? rd_idx : ({{(ADDR_W-1){1'b0}},1'b1}); // rd_idx = 1 if we have more to send
          bram_addr <= 32'd1;   // issue address for next word
          st        <= ST_SEND;
        end

        // -------------------------
        ST_SEND: begin
          if (advance) begin
            if (rd_idx == N_WORDS) begin
              // just sent the final word of the frame
              m_axis_tvalid <= 1'b0;
              m_axis_tlast  <= 1'b0;
              if (AUTO_REARM != 0) begin
                gap_cnt <= {GAP_W{1'b0}};
                st      <= ST_GAP;
              end else begin
                st      <= ST_IDLE;
              end
            end else begin
              // Present next word (bram_dout corresponds to bram_addr from previous cycle)
              m_axis_tdata  <= bram_dout;
              m_axis_tlast  <= (rd_idx == (N_WORDS-1));
              m_axis_tvalid <= 1'b1;

              rd_idx    <= rd_idx + {{(ADDR_W-1){1'b0}},1'b1};
              bram_addr <= bram_addr + 32'd1;
            end
          end
          // If no advance (TREADY=0), we hold tvalid/data/last as required by AXIS.
        end

        // -------------------------
        ST_GAP: begin
          m_axis_tvalid <= 1'b0;
          m_axis_tlast  <= 1'b0;
          if (gap_cnt == GAP_CYC-1) begin
            // restart sequence: address 0 this cycle, data valid next cycle
            rd_idx    <= {ADDR_W{1'b0}};
            bram_addr <= 32'd0;
            st        <= ST_PRIME;
            gap_cnt   <= {GAP_W{1'b0}};
          end else begin
            gap_cnt <= gap_cnt + {{(GAP_W-1){1'b0}},1'b1};
          end
        end

        default: st <= ST_IDLE;
      endcase
    end
  end

endmodule

