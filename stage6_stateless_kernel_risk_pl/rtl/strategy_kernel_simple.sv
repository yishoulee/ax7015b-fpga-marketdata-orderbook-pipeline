// strategy_kernel_simple.sv
`timescale 1ns/1ps

module strategy_kernel_simple #(
    parameter int IMB_THRESHOLD_NUM = 1,  // numerator
    parameter int IMB_THRESHOLD_DEN = 1   // denominator; 3/2 = 1.5x
)(
    input  logic        clk,
    input  logic        rst_n,

    // Best-of-book from Stage 5
    input  logic [31:0] best_bid_price,
    input  logic [31:0] best_bid_qty,
    input  logic [31:0] best_ask_price,
    input  logic [31:0] best_ask_qty,

    // Optional: only act when both sides present
    output logic        book_ready,

    // Strategy output (one-cycle pulse)
    output logic        strat_valid,
    output logic        strat_side,    // 0 = BUY, 1 = SELL
    output logic [31:0] strat_price,
    output logic [31:0] strat_qty
);

    // book is "ready" when both sides are non-empty
    assign book_ready = (best_bid_price != 32'd0) &&
                        (best_ask_price != 32'hffff_ffff);

    // Use simple integer comparison on qtys
    // BUY if bid_qty * DEN > ask_qty * NUM
    // SELL if ask_qty * DEN > bid_qty * NUM
    logic        buy_cond;
    logic        sell_cond;

    // widen to avoid overflow
    logic [63:0] bid_scaled;
    logic [63:0] ask_scaled;

    always_comb begin
        bid_scaled  = best_bid_qty * IMB_THRESHOLD_DEN;
        ask_scaled  = best_ask_qty * IMB_THRESHOLD_DEN;

        // Compare against NUM * other side
        buy_cond  = book_ready &&
                    (bid_scaled > (best_ask_qty * IMB_THRESHOLD_NUM));

        sell_cond = book_ready &&
                    (ask_scaled > (best_bid_qty * IMB_THRESHOLD_NUM));
    end

    // Generate action pulses
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            strat_valid <= 1'b0;
            strat_side  <= 1'b0;
            strat_price <= 32'd0;
            strat_qty   <= 32'd0;
        end else begin
            strat_valid <= 1'b0; // default

            if (buy_cond) begin
                strat_valid <= 1'b1;
                strat_side  <= 1'b0;                   // BUY
                strat_price <= best_ask_price;         // cross at ask
                strat_qty   <= best_bid_qty;           // or some fraction
            end else if (sell_cond) begin
                strat_valid <= 1'b1;
                strat_side  <= 1'b1;                   // SELL
                strat_price <= best_bid_price;         // cross at bid
                strat_qty   <= best_ask_qty;
            end
        end
    end

endmodule
