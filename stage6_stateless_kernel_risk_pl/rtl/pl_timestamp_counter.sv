module pl_timestamp_counter(
    input  logic clk,
    input  logic rst_n,
    output logic [63:0] timestamp
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timestamp <= 64'd0;
        else
            timestamp <= timestamp + 1;
    end
endmodule
