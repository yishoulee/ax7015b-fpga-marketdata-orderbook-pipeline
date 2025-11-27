module top_stage3_serial (
    input  logic clk,            // 50 MHz PL clock (Y14)
    input  logic rst_n,          // active-low reset (or tie high)
    input  logic uart_rx_serial  // from USB-UART TX via header pin
);

    // Byte-level UART signals
    logic       uart_rx_valid;
    logic [7:0] uart_rx_data;

    // Serial UART receiver
    uart_rx_serial #(
        .CLK_FREQ_HZ(50_000_000),
        .BAUD       (115_200)
    ) u_uart_rx_serial (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_serial (uart_rx_serial),
        .rx_valid  (uart_rx_valid),
        .rx_data   (uart_rx_data)
    );

    // Immutable Stage-3 core
    top_stage3_timestamp u_core (
        .clk          (clk),
        .rst_n        (rst_n),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data (uart_rx_data)
    );    

endmodule
