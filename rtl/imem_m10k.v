
module imem_m10k #(
    parameter INIT_FILE = "program.hex"
)(
    output reg [31:0] q,
    input [5:0] read_address,
    input 	 clk
);
    // force M10K ram style
    reg [31:0] mem [0:63] /* synthesis ramstyle = "no_rw_check, M10K" */;
    initial $readmemh(INIT_FILE, mem);

    always @ (posedge clk) begin
        q <= mem[read_address]; // q doesn't get d in this clock cycle
    end
endmodule
