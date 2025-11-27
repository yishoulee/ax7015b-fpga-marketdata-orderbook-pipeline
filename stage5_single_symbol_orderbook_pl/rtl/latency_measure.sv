module latency_measure (
    input  logic clk,
    input  logic rst_n,

    input  logic [63:0] ts_ns,   // host timestamp from record
    input  logic [63:0] pl_now,  // local PL counter
    input  logic        valid,   // align with unpacked record

    output logic [63:0] delta
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            delta <= 64'd0;
        else if (valid)
            delta <= pl_now - ts_ns;
    end
endmodule
