// top_stage5_orderbook.sv
`timescale 1ns/1ps

module top_stage5_orderbook (
    input  logic       clk,
    input  logic       rst_n,

    input  logic uart_rx_serial,   // from M1 pin / USB-UART

    output logic [31:0] best_bid_price,
    output logic [31:0] best_bid_qty,
    output logic [31:0] best_ask_price,
    output logic [31:0] best_ask_qty
);

    import binance_depth_types::*;

    // UART serial -> byte stream
    logic       uart_rx_valid;
    logic [7:0] uart_rx_data;

    uart_rx_serial #(
        .CLK_FREQ_HZ (50_000_000),
        .BAUD        (115_200)
    ) u_uart_rx_serial (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_serial (uart_rx_serial),
        .rx_valid  (uart_rx_valid),
        .rx_data   (uart_rx_data)
    );

    // Stage 2: UART bytes -> 256-bit record stream
    logic [255:0] rec_tdata;
    logic         rec_tvalid;
    logic         rec_tready;
    logic         rec_tlast;

    uart_record_axis_bridge u_uart_record_axis_bridge (
        .clk           (clk),
        .rst_n         (rst_n),
        .uart_rx_valid (uart_rx_valid),
        .uart_rx_data  (uart_rx_data),

        .m_axis_tdata  (rec_tdata),
        .m_axis_tvalid (rec_tvalid),
        .m_axis_tready (rec_tready),
        .m_axis_tlast  (rec_tlast)
    );

    // ------------------------------------------------------------------------
    // Stage 3: timestamp + unpack TLV record
    // ------------------------------------------------------------------------
    // Timestamp
    logic [63:0] pl_now;
    pl_timestamp_counter u_pl_timestamp_counter (
        .clk      (clk),
        .rst_n    (rst_n),
        .timestamp(pl_now)
    );

    // Unpacked event fields
    logic [63:0] ts_ns;
    logic [63:0] update_id;
    logic [7:0]  side;
    logic [31:0] price_f32;
    logic [31:0] qty_f32;

    logic        unpack_valid;
    logic        unpack_last;

    event_record_unpack u_event_record_unpack (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axis_tdata  (rec_tdata),
        .s_axis_tvalid (rec_tvalid),
        .s_axis_tready (rec_tready),
        .s_axis_tlast  (rec_tlast),

        .ts_ns         (ts_ns),
        .update_id     (update_id),
        .side          (side),
        .price_f32     (price_f32),
        .qty_f32       (qty_f32),

        .m_axis_tvalid (unpack_valid),
        .m_axis_tready (1'b1),
        .m_axis_tlast  (unpack_last)
    );

    // Optional: latency measurement from Stage 3
    logic [63:0] latency;
    latency_measure u_latency_measure (
        .clk    (clk),
        .rst_n  (rst_n),
        .ts_ns  (ts_ns),
        .pl_now (pl_now),
        .valid  (unpack_valid),
        .delta  (latency)
    );

    // ------------------------------------------------------------------------
    // Stage 4: depth parser / normalizer
    // ------------------------------------------------------------------------
    depth_event_t depth_ev;
    logic         depth_valid;

    binance_depth_parser u_binance_depth_parser (
        .clk       (clk),
        .rst_n     (rst_n),

        .in_valid  (unpack_valid),
        .ts_ns     (ts_ns),
        .update_id (update_id),
        .side      (side),
        .price_f32 (price_f32),
        .qty_f32   (qty_f32),

        .out_valid (depth_valid),
        .depth_ev  (depth_ev)
    );

    // Packed view for debug (if needed)
    logic [$bits(depth_event_t)-1:0] depth_ev_packed;
    assign depth_ev_packed = depth_ev;

    // Simple depth event counter
    logic [63:0] depth_count;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            depth_count <= 64'd0;
        end else if (depth_valid) begin
            depth_count <= depth_count + 1;
        end
    end

    // ------------------------------------------------------------------------
    // Stage 5: single-symbol order book (best bid/ask only)
    // ------------------------------------------------------------------------
//    logic [31:0] best_bid_price;
//    logic [31:0] best_bid_qty;
//    logic [31:0] best_ask_price;
//    logic [31:0] best_ask_qty;

    pl_order_book #(
        .PRICE_WIDTH (32),
        .QTY_WIDTH   (32)
    ) u_pl_order_book (
        .clk            (clk),
        .rst_n          (rst_n),

        .depth_valid    (depth_valid),
        .depth_ev       (depth_ev),

        .best_bid_price (best_bid_price),
        .best_bid_qty   (best_bid_qty),
        .best_ask_price (best_ask_price),
        .best_ask_qty   (best_ask_qty)
    );

    // Optional: book update counter
    logic [63:0] book_update_count;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            book_update_count <= 64'd0;
        end else if (depth_valid) begin
            book_update_count <= book_update_count + 1;
        end
    end

//    // ------------------------------------------------------------------------
//    // ILA for Stage 5
//    // Reuse your existing ila_0, just adjust probes to what you want to see.
//    // ------------------------------------------------------------------------
//    ila_0 u_ila_0 (
//        .clk   (clk),

//        .probe0 (ts_ns),          // 64
//        .probe1 (update_id),      // 64
//        .probe2 (side),           // 8
//        .probe3 (price_f32),      // 32
//        .probe4 (qty_f32),        // 32
//        .probe5 (depth_valid),    // 1
//        .probe6 (depth_ev_packed),// depth_event_t packed
//        .probe7 (best_bid_price), // 32
//        .probe8 (best_ask_price), // 32
//        .probe9 (best_bid_qty),   // 32
//        .probe10(best_ask_qty)    // 32
//    );
    
//    ila_0 u_ila_0 (
//        .clk   (clk),

//        .probe0 (ts_ns),
//        .probe1 (update_id),
//        .probe2 (side),            // raw side from unpack
//        .probe3 (depth_ev.side),   // enum seen by book
//        .probe4 (price_f32),
//        .probe5 (qty_f32),
//        .probe6 (depth_valid),
//        .probe7 (best_bid_price),
//        .probe8 (best_ask_price),
//        .probe9 (best_bid_qty),
//        .probe10(best_ask_qty)
//    );


endmodule
