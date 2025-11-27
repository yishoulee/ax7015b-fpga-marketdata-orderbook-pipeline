module uart_rx_serial #(
    parameter CLK_FREQ_HZ = 50_000_000,
    parameter BAUD        = 115_200
)(
    input  logic clk,
    input  logic rst_n,

    input  logic rx_serial,      // from USB-UART TX
    output logic rx_valid,       // 1 clk pulse when a byte is ready
    output logic [7:0] rx_data
);

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD;

    typedef enum logic [2:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP,
        S_DONE
    } state_t;

    state_t state, state_next;

    integer clk_cnt, clk_cnt_next;
    integer bit_idx, bit_idx_next;
    logic [7:0] rx_shift, rx_shift_next;

    // Synchronize input (simple 2-flop)
    logic rx_sync1, rx_sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_serial;
            rx_sync2 <= rx_sync1;
        end
    end

    // Next-state logic
    always_comb begin
        state_next    = state;
        clk_cnt_next  = clk_cnt;
        bit_idx_next  = bit_idx;
        rx_shift_next = rx_shift;
        rx_valid      = 1'b0;

        case (state)
            S_IDLE: begin
                if (rx_sync2 == 1'b0) begin // start bit edge
                    state_next   = S_START;
                    clk_cnt_next = 0;
                end
            end

            S_START: begin
                if (clk_cnt == (CLKS_PER_BIT/2)) begin
                    // sample in middle of start bit
                    if (rx_sync2 == 1'b0) begin
                        clk_cnt_next = 0;
                        bit_idx_next = 0;
                        state_next   = S_DATA;
                    end else begin
                        state_next = S_IDLE; // false start
                    end
                end else begin
                    clk_cnt_next = clk_cnt + 1;
                end
            end

            S_DATA: begin
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt_next = 0;
                    rx_shift_next[bit_idx] = rx_sync2;
                    if (bit_idx == 7) begin
                        state_next  = S_STOP;
                    end else begin
                        bit_idx_next = bit_idx + 1;
                    end
                end else begin
                    clk_cnt_next = clk_cnt + 1;
                end
            end

            S_STOP: begin
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt_next = 0;
                    state_next   = S_DONE;
                end else begin
                    clk_cnt_next = clk_cnt + 1;
                end
            end

            S_DONE: begin
                rx_valid      = 1'b1;
                state_next    = S_IDLE;
                rx_shift_next = rx_shift;
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

    // Sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            clk_cnt  <= 0;
            bit_idx  <= 0;
            rx_shift <= 8'h00;
            rx_data  <= 8'h00;
        end else begin
            state    <= state_next;
            clk_cnt  <= clk_cnt_next;
            bit_idx  <= bit_idx_next;
            rx_shift <= rx_shift_next;

            if (state == S_DONE)
                rx_data <= rx_shift;
        end
    end

endmodule
