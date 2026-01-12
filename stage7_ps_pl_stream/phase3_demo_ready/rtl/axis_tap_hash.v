`timescale 1ns/1ps

module axis_tap_hash #(
    parameter [31:0] HASH_INIT  = 32'h811C9DC5, // FNV-1a offset basis
    parameter [31:0] HASH_PRIME = 32'h01000193  // FNV-1a prime
)(
    input  wire        aclk,
    input  wire        aresetn,

    // AXI-Stream slave (in)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // AXI-Stream master (out)
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    // Debug outputs (sync to aclk)
    output reg  [31:0] last_hash,
    output reg  [31:0] word_count,
    output reg  [31:0] pkt_count
);

    // Pure pass-through (no buffering)
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;
    assign s_axis_tready = m_axis_tready;

    wire beat = s_axis_tvalid && s_axis_tready;

    reg [31:0] hash;
    reg [31:0] next_hash;

    always @(*) begin
        // FNV-1a update
        next_hash = (hash ^ s_axis_tdata) * HASH_PRIME;
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            hash       <= HASH_INIT;
            last_hash  <= 32'h0;
            word_count <= 32'h0;
            pkt_count  <= 32'h0;
        end else begin
            if (beat) begin
                word_count <= word_count + 1;

                if (s_axis_tlast) begin
                    // latch final hash for this packet
                    last_hash <= next_hash;
                    pkt_count <= pkt_count + 1;
                    hash      <= HASH_INIT;   // reset per packet
                end else begin
                    hash <= next_hash;
                end
            end
        end
    end

endmodule
