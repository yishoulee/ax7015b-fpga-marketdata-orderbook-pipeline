package binance_depth_types;

    typedef enum logic [0:0] {
        SIDE_BID = 1'b0,
        SIDE_ASK = 1'b1
    } side_t;

    typedef struct packed {
        logic [63:0] ts_rx_ns;
        logic [63:0] update_id;
        side_t       side;
        logic [31:0] price_fp;
        logic [31:0] qty_fp;
        logic [7:0]  flags;
    } depth_event_t;

endpackage
