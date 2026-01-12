`timescale 1ns/1ps

module axis_tap_hash_axil #(
    parameter integer AXIL_ADDR_WIDTH = 6,
    parameter integer AXIL_DATA_WIDTH = 32
)(
    input  wire                         aclk,
    input  wire                         aresetn,

    // AXI-Stream in
    input  wire [31:0]                  s_axis_tdata,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tlast,

    // AXI-Stream out
    output wire [31:0]                  m_axis_tdata,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready,
    output wire                         m_axis_tlast,

    // AXI-Lite slave
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,

    input  wire [AXIL_DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [(AXIL_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,

    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,

    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,

    output wire [AXIL_DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready
);

    wire [31:0] last_hash;
    wire [31:0] word_count;
    wire [31:0] pkt_count;

    axis_tap_hash u_tap (
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axis_tdata (s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast (s_axis_tlast),

        .m_axis_tdata (m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast (m_axis_tlast),

        .last_hash (last_hash),
        .word_count(word_count),
        .pkt_count (pkt_count)
    );

    axil_ro_regs #(
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .DATA_WIDTH(AXIL_DATA_WIDTH)
    ) u_axil (
        .ACLK(aclk),
        .ARESETN(aresetn),

        .S_AXI_AWADDR (s_axi_awaddr),
        .S_AXI_AWVALID(s_axi_awvalid),
        .S_AXI_AWREADY(s_axi_awready),

        .S_AXI_WDATA  (s_axi_wdata),
        .S_AXI_WSTRB  (s_axi_wstrb),
        .S_AXI_WVALID (s_axi_wvalid),
        .S_AXI_WREADY (s_axi_wready),

        .S_AXI_BRESP  (s_axi_bresp),
        .S_AXI_BVALID (s_axi_bvalid),
        .S_AXI_BREADY (s_axi_bready),

        .S_AXI_ARADDR (s_axi_araddr),
        .S_AXI_ARVALID(s_axi_arvalid),
        .S_AXI_ARREADY(s_axi_arready),

        .S_AXI_RDATA  (s_axi_rdata),
        .S_AXI_RRESP  (s_axi_rresp),
        .S_AXI_RVALID (s_axi_rvalid),
        .S_AXI_RREADY (s_axi_rready),

        .ro_last_hash (last_hash),
        .ro_word_count(word_count),
        .ro_pkt_count (pkt_count)
    );

endmodule
