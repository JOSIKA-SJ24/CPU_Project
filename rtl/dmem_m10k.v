module dmem_m10k #(
    parameter INIT_FILE = "data.hex"
)(
    output reg [15:0] q,
    input [15:0] d,
    input [5:0] write_address, read_address,
    input we, clk
);
    // force M10K ram style
    reg [15:0] mem [0:63] /* synthesis ramstyle = "no_rw_check, M10K" */;
    initial $readmemh(INIT_FILE, mem);

    always @ (posedge clk) begin
        if (we) begin
            mem[write_address] <= d;
        end
        q <= mem[read_address]; // q doesn't get d in this clock cycle
    end
endmodule