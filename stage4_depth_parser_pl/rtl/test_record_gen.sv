// test_record_gen.sv
module test_record_gen (
    input  logic         clk,
    input  logic         rst_n,
    output logic [255:0] m_axis_tdata,
    output logic         m_axis_tvalid,
    input  logic         m_axis_tready,
    output logic         m_axis_tlast
);
    // One-shot generator: emit one record when ready
    typedef enum logic [1:0] {IDLE, SEND} state_t;
    state_t state;

    // Constants matching the host struct <QQBffxxxxxxx>
    localparam logic [63:0] TS_NS_CONST     = 64'd1234567890123456789;
    localparam logic [63:0] UPDATE_ID_CONST = 64'd9876543210;
    localparam logic [7:0]  SIDE_CONST      = 8'd1;           // ask
    localparam logic [31:0] PRICE_F32_CONST = 32'h42C90000;   // 100.5f
    localparam logic [31:0] QTY_F32_CONST   = 32'h3E800000;   // 0.25f
    localparam logic [55:0] PAD_CONST       = 56'd0;          // 7 bytes padding

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (m_axis_tready) begin
                        // Layout: [255:200]=pad, [199:168]=qty_f32, [167:136]=price_f32,
                        //         [135:128]=side, [127:64]=update_id, [63:0]=ts_ns
                        m_axis_tdata  <= {
                            PAD_CONST,
                            QTY_F32_CONST,
                            PRICE_F32_CONST,
                            SIDE_CONST,
                            UPDATE_ID_CONST,
                            TS_NS_CONST
                        };
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1;
                        state         <= SEND;
                    end
                end

                SEND: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        m_axis_tvalid <= 1'b0;
                        m_axis_tlast  <= 1'b0;
                        // You can either go back to IDLE (emit repeatedly) or stay DONE.
                        state         <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
