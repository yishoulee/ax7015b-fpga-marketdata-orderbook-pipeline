`timescale 1ns/1ps

module axil_ro_regs #(
    parameter integer ADDR_WIDTH = 6,   // 64B
    parameter integer DATA_WIDTH = 32
)(
    input  wire                    ACLK,
    input  wire                    ARESETN,

    // AXI-Lite slave interface
    input  wire [ADDR_WIDTH-1:0]   S_AXI_AWADDR,
    input  wire                    S_AXI_AWVALID,
    output reg                     S_AXI_AWREADY,

    input  wire [DATA_WIDTH-1:0]   S_AXI_WDATA,
    input  wire [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                    S_AXI_WVALID,
    output reg                     S_AXI_WREADY,

    output reg  [1:0]              S_AXI_BRESP,
    output reg                     S_AXI_BVALID,
    input  wire                    S_AXI_BREADY,

    input  wire [ADDR_WIDTH-1:0]   S_AXI_ARADDR,
    input  wire                    S_AXI_ARVALID,
    output reg                     S_AXI_ARREADY,

    output reg  [DATA_WIDTH-1:0]   S_AXI_RDATA,
    output reg  [1:0]              S_AXI_RRESP,
    output reg                     S_AXI_RVALID,
    input  wire                    S_AXI_RREADY,

    // Read-only values to expose
    input  wire [31:0]             ro_last_hash,
    input  wire [31:0]             ro_word_count,
    input  wire [31:0]             ro_pkt_count
);

    // This is a minimal AXI-Lite slave:
    // - Reads supported (single outstanding)
    // - Writes accepted but ignored, returns OKAY

    localparam [1:0] OKAY  = 2'b00;

    // Write channel: always ready, ignore data, respond OKAY once per write handshake
    wire aw_hs = S_AXI_AWVALID && S_AXI_AWREADY;
    wire w_hs  = S_AXI_WVALID  && S_AXI_WREADY;

    reg aw_seen;
    reg w_seen;

    // Read channel: capture ARADDR and respond with RO data
    reg [ADDR_WIDTH-1:0] araddr_latched;

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_AWREADY <= 1'b1;
            S_AXI_WREADY  <= 1'b1;
            S_AXI_BRESP   <= OKAY;
            S_AXI_BVALID  <= 1'b0;
            aw_seen       <= 1'b0;
            w_seen        <= 1'b0;

            S_AXI_ARREADY <= 1'b1;
            S_AXI_RDATA   <= {DATA_WIDTH{1'b0}};
            S_AXI_RRESP   <= OKAY;
            S_AXI_RVALID  <= 1'b0;
            araddr_latched<= {ADDR_WIDTH{1'b0}};
        end else begin
            // -------------------------
            // WRITE (ignored, but ack)
            // -------------------------
            if (aw_hs) aw_seen <= 1'b1;
            if (w_hs)  w_seen  <= 1'b1;

            // When both seen, issue BVALID (one response)
            if (!S_AXI_BVALID && (aw_seen && w_seen)) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= OKAY;
                aw_seen      <= 1'b0;
                w_seen       <= 1'b0;
            end

            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

            // Keep ready asserted (simple slave)
            S_AXI_AWREADY <= 1'b1;
            S_AXI_WREADY  <= 1'b1;

            // -------------------------
            // READ
            // -------------------------
            if (S_AXI_ARVALID && S_AXI_ARREADY && !S_AXI_RVALID) begin
                araddr_latched <= S_AXI_ARADDR;

                // decode word address (byte offsets)
                case (S_AXI_ARADDR[5:2]) // 32-bit words within 64B
                    4'h0: S_AXI_RDATA <= ro_last_hash;
                    4'h1: S_AXI_RDATA <= ro_word_count;
                    4'h2: S_AXI_RDATA <= ro_pkt_count;
                    default: S_AXI_RDATA <= 32'h0;
                endcase

                S_AXI_RRESP <= OKAY;
                S_AXI_RVALID<= 1'b1;
            end

            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end

            // ARREADY is deasserted only when holding an unread RVALID
            S_AXI_ARREADY <= !S_AXI_RVALID;
        end
    end

endmodule
