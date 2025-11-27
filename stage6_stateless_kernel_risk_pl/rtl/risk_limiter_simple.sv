// risk_limiter_simple.sv
`timescale 1ns/1ps

module risk_limiter_simple #(
    parameter int WINDOW_CYCLES          = 500_000, // cycles per window
    parameter int MAX_ACTIONS_PER_WINDOW = 5
)(
    input  logic        clk,
    input  logic        rst_n,

    // Kill switch (1 = enabled, 0 = block all)
    input  logic        kill_enable,

    // Incoming strategy requests
    input  logic        in_valid,
    input  logic        in_side,       // 0 = BUY, 1 = SELL
    input  logic [31:0] in_price,
    input  logic [31:0] in_qty,

    // Approved actions
    output logic        out_valid,
    output logic        out_side,
    output logic [31:0] out_price,
    output logic [31:0] out_qty,

    // Status/debug
    output logic        throttled,     // 1 if we dropped due to rate limit
    output logic [31:0] action_count   // actions in current window
);

    // simple fixed window: count cycles; reset every WINDOW_CYCLES
    logic [31:0] cycle_count;
    logic [31:0] action_count_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count     <= 32'd0;
            action_count_r  <= 32'd0;
        end else begin
            if (cycle_count == WINDOW_CYCLES - 1) begin
                cycle_count    <= 32'd0;
                action_count_r <= 32'd0;
            end else begin
                cycle_count    <= cycle_count + 1;
            end

            // increment only when we actually pass an action
            if (out_valid) begin
                action_count_r <= action_count_r + 1;
            end
        end
    end

    assign action_count = action_count_r;

    // combinational decision
    logic can_send;
    always_comb begin
        // default: block
        out_valid  = 1'b0;
        out_side   = in_side;
        out_price  = in_price;
        out_qty    = in_qty;
        throttled  = 1'b0;

        can_send = (kill_enable == 1'b1) &&
                   (action_count_r < MAX_ACTIONS_PER_WINDOW);

        if (in_valid) begin
            if (can_send) begin
                out_valid = 1'b1;
            end else begin
                throttled = 1'b1;
            end
        end
    end

endmodule
