// event_record_types.sv
package event_record_types;

  // Replace this with your actual struct layout from Stage 3.
  //
  // Example ONLY - you must use the same fields and order that your
  // Stage 3 path already uses when packing/unpacking the 256-bit bus.
  //
  typedef struct packed {
    logic [63:0] ts_ns;
    logic [63:0] update_id;
    logic        side_bit;   // 0 = bid, 1 = ask
    logic [31:0] price_q32;
    logic [31:0] qty_q32;
    logic [31:0] reserved;
  } event_record_t;

endpackage : event_record_types
