// =============================================================
// MAC unit: multiply-accumulate with a 48-bit accumulator (ACC).
// Used by CLRACC (ACC = 0) and MAC (ACC = ACC + R[rs1] * R[rs2]).
//
// Why 48 bits (Prof. Land, Oct 28): a signed 16 x 16 product is
// 32 bits, so 48 bits leaves 16 bits of headroom for summing many
// products, and the ACC can be read out as exactly three 16-bit
// slices (ACCOUT sel = 0, 1, 2).
//
// The multiplier and adder are combinational (wires). The ACC is a
// register: it only changes on a clock edge, and the CPU only lets
// it change in the COMMIT state (acc_write / acc_clear are gated
// with commit in cpu.v), like every other write in the CPU.
// =============================================================
module mac (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] a,          // R[rs1], treated as signed
    input  wire [15:0] b,          // R[rs2], treated as signed
    input  wire        acc_write,  // 1 = ACC <= ACC + a*b   (MAC,    only in COMMIT)
    input  wire        acc_clear,  // 1 = ACC <= 0           (CLRACC, only in COMMIT)
    output reg  [47:0] acc         // the accumulator
);
    // Signed 16 x 16 = 32-bit product. $signed makes Verilog treat the
    // bit patterns as two's complement, so -2 * 3 gives -6, not 196602.
    wire signed [31:0] product = $signed(a) * $signed(b);

    // Sign-extend the product to 48 bits before adding: copy bit 31
    // (the sign) into the 16 new upper bits, so a negative product
    // stays negative in the wider ACC.
    wire [47:0] product48 = {{16{product[31]}}, product};

    always @(posedge clk) begin
        if (reset)          acc <= 48'd0;              // known state at power-up
        else if (acc_clear) acc <= 48'd0;              // CLRACC
        else if (acc_write) acc <= acc + product48;    // MAC: keeps the low 48 bits (wraps, no flags)
    end
endmodule
