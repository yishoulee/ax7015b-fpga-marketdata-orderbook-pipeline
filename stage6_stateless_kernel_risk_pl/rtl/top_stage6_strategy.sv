// top_stage6_strategy.sv
`timescale 1ns/1ps

module top_stage6_strategy (
    input  logic clk,
    input  logic rst_n,
    input  logic uart_rx_serial
//    input  logic kill_enable    // can be tied to constant 1'b1 for now
);
    // Best-of-book outputs from Stage 5
    logic [31:0] best_bid_price;
    logic [31:0] best_bid_qty;
    logic [31:0] best_ask_price;
    logic [31:0] best_ask_qty;

    // ... [Everything from top_stage5_orderbook up to and including
    // pl_order_book + best_bid/ask signals] ...
    top_stage5_orderbook u_top_stage5_orderbook (
        .clk            (clk),
        .rst_n          (rst_n),
        .uart_rx_serial (uart_rx_serial),

        .best_bid_price (best_bid_price),
        .best_bid_qty   (best_bid_qty),
        .best_ask_price (best_ask_price),
        .best_ask_qty   (best_ask_qty)
    );

    // Strategy kernel
    logic        book_ready;
    logic        strat_valid;
    logic        strat_side;
    logic [31:0] strat_price;
    logic [31:0] strat_qty;

    strategy_kernel_simple u_strategy_kernel_simple (
        .clk            (clk),
        .rst_n          (rst_n),

        .best_bid_price (best_bid_price),
        .best_bid_qty   (best_bid_qty),
        .best_ask_price (best_ask_price),
        .best_ask_qty   (best_ask_qty),

        .book_ready     (book_ready),

        .strat_valid    (strat_valid),
        .strat_side     (strat_side),
        .strat_price    (strat_price),
        .strat_qty      (strat_qty)
    );

    // Risk limiter
    logic        act_valid;
    logic        act_side;
    logic [31:0] act_price;
    logic [31:0] act_qty;
    logic        throttled;
    logic [31:0] action_count;

    risk_limiter_simple u_risk_limiter_simple (
        .clk                   (clk),
        .rst_n                 (rst_n),

//        .kill_enable           (kill_enable),
        .kill_enable           (1'b1),

        .in_valid              (strat_valid),
        .in_side               (strat_side),
        .in_price              (strat_price),
        .in_qty                (strat_qty),

        .out_valid             (act_valid),
        .out_side              (act_side),
        .out_price             (act_price),
        .out_qty               (act_qty),

        .throttled             (throttled),
        .action_count          (action_count)
    );

    // ILA: add probes for strategy + risk
    ila_0 u_ila_0 (
        .clk   (clk),
    
        .probe0 (act_price),        // 32
        .probe1 (act_side),         // 1
        .probe2 (act_valid),        // 1
        .probe3 (best_ask_price),   // 32
        .probe4 (best_ask_qty),     // 32
        .probe5 (best_bid_price),   // 32
        .probe6 (best_bid_qty),     // 32
        .probe7 (strat_price),      // 32
        .probe8 (strat_qty),        // 32
        .probe9 (strat_side),       // 1
        .probe10(strat_valid)       // 1
    );
        
endmodule
