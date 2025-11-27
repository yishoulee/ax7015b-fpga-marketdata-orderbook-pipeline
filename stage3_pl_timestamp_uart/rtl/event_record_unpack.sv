// event_record_unpack.sv
module event_record_unpack (
    input  logic         clk,
    input  logic         rst_n,

    // single-beat input from UART bridge or internal generator
    input  logic [255:0] s_axis_tdata,
    input  logic         s_axis_tvalid,
    output logic         s_axis_tready,
    input  logic         s_axis_tlast,

    // unpacked fields
    output logic [63:0]  ts_ns,
    output logic [63:0]  update_id,
    output logic [7:0]   side,
    output logic [31:0]  price_f32,
    output logic [31:0]  qty_f32,

    // output handshake
    output logic         m_axis_tvalid,
    input  logic         m_axis_tready,
    output logic         m_axis_tlast
);

    // Always ready when output not holding data
    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ts_ns         <= '0;
            update_id     <= '0;
            side          <= '0;
            price_f32     <= '0;
            qty_f32       <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            // drop output when consumed
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            // on new input word, slice fields directly
            if (s_axis_tvalid && s_axis_tready) begin
                // layout matches your generator and the rec_tdata you see:
                // [255:200] 7B padding
                // [199:168] qty_f32
                // [167:136] price_f32
                // [135:128] side
                // [127:64]  update_id
                // [63:0]    ts_ns
                ts_ns     <= s_axis_tdata[ 63:  0];
                update_id <= s_axis_tdata[127: 64];
                side      <= s_axis_tdata[135:128];
                price_f32 <= s_axis_tdata[167:136];
                qty_f32   <= s_axis_tdata[199:168];

                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= s_axis_tlast;
            end
        end
    end

endmodule
