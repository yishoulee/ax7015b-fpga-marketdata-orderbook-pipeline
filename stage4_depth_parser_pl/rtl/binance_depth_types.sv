// binance_depth_types.sv
package binance_depth_types;

  // Import your existing event_record_t from Stage 3.
  // Adjust the package/import to whatever you are actually using.
  import event_record_types::*;
 
  // Side encoding
  typedef enum logic [0:0] {
    SIDE_BID = 1'b0,
    SIDE_ASK = 1'b1
  } side_t;

  // Record type encoding
  typedef enum logic [1:0] {
    REC_TYPE_SNAP  = 2'b00,
    REC_TYPE_DELTA = 2'b01
  } rec_type_t;

  // Normalized single depth event.
  //
  // We keep this per-price-level for now:
  // one record = one (side, price, qty, updateId) change.
  //
  // Stage 5 can build top-N book views from this stream.
  //
  typedef struct packed {
    rec_type_t  rec_type;     // snapshot vs delta
    side_t      side;         // bid / ask

    logic [15:0] symbol_id;   // you can hardcode if single symbol for now
    logic [63:0] ts_rx_ns;    // receive timestamp
    logic [63:0] update_id;   // Binance updateId

    logic [31:0] price_fp;    // fixed-point price
    logic [31:0] qty_fp;      // fixed-point quantity

    // optional flags (you can extend later)
    logic [7:0]  flags;
  } depth_event_t;

endpackage : binance_depth_types
