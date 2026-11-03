// =============================================================
// ALU (the "16-bit execution unit" box): a calculator.
// Pure combinational logic: no clock, no memory.
// The answer changes the instant A, B or op change.
// =============================================================
module alu (
    input  wire [15:0] a,       // input A  (always R[rs1])
    input  wire [15:0] b,       // input B  (R[rs2] or the immediate, chosen by BSel)
    input  wire [1:0]  op,      // ALUOp from the control unit
    output reg  [15:0] y        // result  (ExecResult16)
);
    localparam ALU_ADD = 2'd0;
    localparam ALU_SUB = 2'd1;  // TODO (SUB owner): add the SUB case below

    always @(*) begin
        case (op)
            ALU_ADD: y = a + b;   // keeps the low 16 bits: wraps around, no flags
            default: y = 16'd0;
        endcase
    end
endmodule
