`timescale 1ns/1ps

module tb_stage3_timestamp;

    // Clock and reset
    logic clk;
    logic rst_n;

    // UART interface to DUT
    logic       uart_rx_valid;
    logic [7:0] uart_rx_data;

    // DUT instance
    top_stage3_timestamp dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data (uart_rx_data)
    );

    // 100 MHz clock: period 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Test record bytes (from Python struct <QQBffxxxxxxx>)
    // ts_ns     = 1234567890123456789
    // update_id = 9876543210
    // side      = 1
    // price     = 100.5f
    // qty       = 0.25f
    byte record_bytes [0:31] = '{
        8'h15, 8'h81, 8'hE9, 8'h7D,
        8'hF4, 8'h10, 8'h22, 8'h11,
        8'hEA, 8'h16, 8'hB0, 8'h4C,
        8'h02, 8'h00, 8'h00, 8'h00,
        8'h01, 8'h00, 8'h00, 8'hC9,
        8'h42, 8'h00, 8'h00, 8'h80,
        8'h3E, 8'h00, 8'h00, 8'h00,
        8'h00, 8'h00, 8'h00, 8'h00
    };

    integer i;

    initial begin
        // Init
        rst_n         = 1'b0;
        uart_rx_valid = 1'b0;
        uart_rx_data  = 8'h00;

        // Hold reset for a few cycles
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        // Wait a bit after reset
        repeat (10) @(posedge clk);

        // Send 32 bytes, one per clock
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            uart_rx_valid <= 1'b1;
            uart_rx_data  <= record_bytes[i];
        end

        // Deassert valid after last byte
        @(posedge clk);
        uart_rx_valid <= 1'b0;
        uart_rx_data  <= 8'h00;

        // Let things settle
        repeat (50) @(posedge clk);

        $finish;
    end

endmodule
