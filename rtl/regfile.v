// =============================================================
// Register file: 16 registers, each 16 bits wide.
//   - 2 read ports  (A and B) -> can read two registers at once
//   - 1 write port            -> saves one register per instruction
//   - R0 always reads 0, and writes to R0 are ignored
// Slide link: the "Register file" box on every walkthrough slide.
// =============================================================
module regfile (
    input  wire        clk,
    input  wire        reset,
    // read port A  (always rs1)
    input  wire [3:0]  ra,        // which register to read
    output wire [15:0] a_data,    // its value  (A16 on the slides)
    // read port B  (always rs2)
    input  wire [3:0]  rb,
    output wire [15:0] b_data,    // B16 on the slides
    // write port
    input  wire        we,        // write enable  (RegWrite, only on in COMMIT)
    input  wire [3:0]  wa,        // which register to write  (rd)
    input  wire [15:0] w_data     // value to write  (WB_DATA16, from the writeback mux)
);
    reg [15:0] r [0:15];          // the 16 storage boxes
    integer i;

    // Reading is just wires: the value appears as soon as ra/rb change.
    // R0 is forced to 0 here, so it can never hold anything else.
    assign a_data = (ra == 4'd0) ? 16'd0 : r[ra];
    assign b_data = (rb == 4'd0) ? 16'd0 : r[rb];

    // Writing only happens on a clock edge, and only if we is 1.
    // The (wa != 0) part is the "writes to R0 are discarded" rule.
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) r[i] <= 16'd0;
        end else if (we && wa != 4'd0) begin
            r[wa] <= w_data;
        end
    end
endmodule
