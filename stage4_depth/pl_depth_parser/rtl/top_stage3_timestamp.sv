module top_stage3_timestamp (
    input  logic         clk,
    input  logic         rst_n,

    // UART byte stream from UART RX core
    input  logic         uart_rx_valid,
    input  logic [7:0]   uart_rx_data

    // You can add more ports later (e.g. debug, LEDs, etc.)
);

    // Bridge: UART bytes -> 256-bit AXI-like stream
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

//    // For Stage-3-internal variant, ignore UART bridge and use generator
//    test_record_gen u_test_record_gen (
//        .clk          (clk),
//        .rst_n        (rst_n),
//        .m_axis_tdata (rec_tdata),
//        .m_axis_tvalid(rec_tvalid),
//        .m_axis_tready(rec_tready),
//        .m_axis_tlast (rec_tlast)
//    );

    // Timestamp counter
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
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axis_tdata (rec_tdata),
        .s_axis_tvalid(rec_tvalid),
        .s_axis_tready(rec_tready),
        .s_axis_tlast (rec_tlast),

        .ts_ns        (ts_ns),
        .update_id    (update_id),
        .side         (side),
        .price_f32    (price_f32),
        .qty_f32      (qty_f32),

        .m_axis_tvalid(unpack_valid),
        .m_axis_tready(1'b1),     // no backpressure for now
        .m_axis_tlast (unpack_last)
    );

    // Latency measurement
    logic [63:0] latency;
    latency_measure u_latency_measure (
        .clk    (clk),
        .rst_n  (rst_n),
        .ts_ns  (ts_ns),
        .pl_now (pl_now),
        .valid  (unpack_valid),
        .delta  (latency)
    );

    // Stage 4: depth parser
    import binance_depth_types::*;

    depth_event_t depth_ev;
    logic         depth_valid;

    binance_depth_parser u_binance_depth_parser (
        .clk       (clk),
        .rst_n     (rst_n),

        // input from event_record_unpack
        .in_valid  (unpack_valid),
        .ts_ns     (ts_ns),
        .update_id (update_id),
        .side      (side),
        .price_f32 (price_f32),
        .qty_f32   (qty_f32),

        // output normalized depth event
        .out_valid (depth_valid),
        .depth_ev  (depth_ev)
    );
    
    
//    // Simple event counter
//    logic [63:0] depth_count;
//    always_ff @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            depth_count <= 64'd0;
//        end else if (depth_valid) begin
//            depth_count <= depth_count + 1;
//        end
//    end
    
    logic [$bits(depth_event_t)-1:0] depth_ev_packed;
    assign depth_ev_packed = depth_ev;

    ila_0 u_ila_0 (
        .clk   (clk),
    
        .probe0(ts_ns),
        .probe1(update_id),
        .probe2(side),
        .probe3(price_f32),
        .probe4(qty_f32),
        .probe5(rec_tvalid),
        .probe6(uart_rx_data),
        .probe7(uart_rx_valid),
        .probe8(unpack_valid),
        .probe9(latency),
        .probe10(depth_ev_packed)
//        .probe10(depth_count)
    );
            
endmodule
