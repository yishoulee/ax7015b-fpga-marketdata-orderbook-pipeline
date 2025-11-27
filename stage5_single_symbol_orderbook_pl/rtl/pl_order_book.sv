// pl_order_book.sv
`timescale 1ns/1ps

module pl_order_book #(
    parameter PRICE_WIDTH = 32,
    parameter QTY_WIDTH   = 32
) (
    input  logic clk,
    input  logic rst_n,

    // Input depth events from Stage 4
    input  logic                     depth_valid,
    input  binance_depth_types::depth_event_t depth_ev,

    // Best bid / ask outputs
    output logic [PRICE_WIDTH-1:0]   best_bid_price,
    output logic [QTY_WIDTH-1:0]     best_bid_qty,
    output logic [PRICE_WIDTH-1:0]   best_ask_price,
    output logic [QTY_WIDTH-1:0]     best_ask_qty
);

    import binance_depth_types::*;

    // Internal registers for best-of-book
    logic [PRICE_WIDTH-1:0] best_bid_price_r, best_bid_price_n;
    logic [QTY_WIDTH-1:0]   best_bid_qty_r,   best_bid_qty_n;

    logic [PRICE_WIDTH-1:0] best_ask_price_r, best_ask_price_n;
    logic [QTY_WIDTH-1:0]   best_ask_qty_r,   best_ask_qty_n;

    // Simple encoding assumption:
    // - qty_fp == 0 => delete at that price
    // - qty_fp > 0  => insert/update at that price
    // - SIDE_BID / SIDE_ASK from binance_depth_types

    // Sequential state update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            best_bid_price_r <= '0;
            best_bid_qty_r   <= '0;

            best_ask_price_r <= {PRICE_WIDTH{1'b1}}; // treat max price as "no ask"
            best_ask_qty_r   <= '0;
        end
        else begin
            best_bid_price_r <= best_bid_price_n;
            best_bid_qty_r   <= best_bid_qty_n;

            best_ask_price_r <= best_ask_price_n;
            best_ask_qty_r   <= best_ask_qty_n;
        end
    end

    // Combinational next-state logic
    always_comb begin
        // default: hold current values
        best_bid_price_n = best_bid_price_r;
        best_bid_qty_n   = best_bid_qty_r;

        best_ask_price_n = best_ask_price_r;
        best_ask_qty_n   = best_ask_qty_r;

        if (depth_valid) begin
            // BID side
            if (depth_ev.side == SIDE_BID) begin
                if (depth_ev.qty_fp == '0) begin
                    // deletion at this price; if it is the current best, drop it
                    if (depth_ev.price_fp == best_bid_price_r) begin
                        best_bid_price_n = '0;
                        best_bid_qty_n   = '0;
                    end
                    // else ignore for now (no rescan)
                end
                else begin
                    // insert/update: update best if price is higher, or book is empty
                    if (best_bid_qty_r == '0 || depth_ev.price_fp > best_bid_price_r) begin
                        best_bid_price_n = depth_ev.price_fp;
                        best_bid_qty_n   = depth_ev.qty_fp;
                    end
                end
            end
            // ASK side
            else if (depth_ev.side == SIDE_ASK) begin
                if (depth_ev.qty_fp == '0) begin
                    if (depth_ev.price_fp == best_ask_price_r) begin
                        best_ask_price_n = {PRICE_WIDTH{1'b1}};
                        best_ask_qty_n   = '0;
                    end
                end
                else begin
                    // insert/update: update best if price is lower, or ask book empty
                    if (best_ask_qty_r == '0 || depth_ev.price_fp < best_ask_price_r) begin
                        best_ask_price_n = depth_ev.price_fp;
                        best_ask_qty_n   = depth_ev.qty_fp;
                    end
                end
            end
        end
    end

    // Drive outputs
    assign best_bid_price = best_bid_price_r;
    assign best_bid_qty   = best_bid_qty_r;

    assign best_ask_price = best_ask_price_r;
    assign best_ask_qty   = best_ask_qty_r;

endmodule
