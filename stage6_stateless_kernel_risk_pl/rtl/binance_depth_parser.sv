module binance_depth_parser (
    input  logic clk,
    input  logic rst_n,

    input  logic        in_valid,
    input  logic [63:0] ts_ns,
    input  logic [63:0] update_id,
    input  logic [7:0]  side,        // raw 0/1 from unpack
    input  logic [31:0] price_f32,
    input  logic [31:0] qty_f32,

    output logic                           out_valid,
    output binance_depth_types::depth_event_t depth_ev
);
    import binance_depth_types::*;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            depth_ev  <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                depth_ev.ts_rx_ns  <= ts_ns;
                depth_ev.update_id <= update_id;
                depth_ev.price_fp  <= price_f32;
                depth_ev.qty_fp    <= qty_f32;
                depth_ev.flags     <= 8'd0;

                if (side == 8'd0)
                    depth_ev.side <= SIDE_BID;
                else
                    depth_ev.side <= SIDE_ASK;
            end
        end
    end
endmodule
