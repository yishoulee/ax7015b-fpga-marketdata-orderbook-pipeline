// uart_record_axis_bridge.sv
module uart_record_axis_bridge #(
    parameter int RECORD_BYTES = 32
) (
    input  logic         clk,
    input  logic         rst_n,

    // incoming bytes from UART RX core
    input  logic         uart_rx_valid,
    input  logic [7:0]   uart_rx_data,

    // one 256-bit word per record
    output logic [255:0] m_axis_tdata,
    output logic         m_axis_tvalid,
    input  logic         m_axis_tready,
    output logic         m_axis_tlast
);

    logic [5:0] byte_idx;   // 0..31
    logic       primed;     // have we dropped the first junk byte?

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_idx      <= '0;
            primed        <= 1'b0;
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            // clear valid when downstream accepts the word
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            if (uart_rx_valid) begin
                if (!primed) begin
                    // Drop the very first byte after reset (it's 0x00 in your capture)
                    primed   <= 1'b1;
                    byte_idx <= 6'd0;
                end else begin
                    // Normal operation: pack bytes sequentially
                    m_axis_tdata[8*byte_idx +: 8] <= uart_rx_data;

                    if (byte_idx == RECORD_BYTES-1) begin
                        byte_idx      <= 6'd0;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1;
                    end else begin
                        byte_idx <= byte_idx + 6'd1;
                    end
                end
            end
        end
    end

endmodule
