`timescale 1ns/1ps

module binance_depth_parser (
    input  logic clk,
    input  logic rst_n,

    // Input from event_record_unpack
    input  logic        in_valid,
    input  logic [63:0] ts_ns,
    input  logic [63:0] update_id,
    input  logic [7:0]  side,       // your unpacked side byte
    input  logic [31:0] price_f32,
    input  logic [31:0] qty_f32,

    // Output normalized depth event
    output logic                         out_valid,
    output binance_depth_types::depth_event_t depth_ev
);

    import binance_depth_types::*;

    depth_event_t depth_next;

    // Combinational mapping from unpacked fields to normalized event
    always_comb begin
        depth_next = '0;

        depth_next.rec_type  = REC_TYPE_DELTA;  // only deltas for now
        depth_next.side      = side[0] ? SIDE_ASK : SIDE_BID;
        depth_next.symbol_id = 16'd0;          // single symbol

        depth_next.ts_rx_ns  = ts_ns;
        depth_next.update_id = update_id;

        depth_next.price_fp  = price_f32;
        depth_next.qty_fp    = qty_f32;

        depth_next.flags     = 8'h00;
    end

    // One-stage register for timing/valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            depth_ev   <= '0;
            out_valid  <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                depth_ev <= depth_next;
            end
        end
    end

endmodule
