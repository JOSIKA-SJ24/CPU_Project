// =============================================================
// Control unit: the decoder that turns an opcode into switch settings.
// This is your "Control settings per instruction" table, written as code.
// Each 'case' below is one ROW of that table.
//
// It only says what the switches WOULD be. The CPU's state machine
// (in cpu.v) decides WHEN the write enables are actually allowed to fire
// (only in the COMMIT step).
// =============================================================
module control (
    input  wire [7:0] opcode,
    output reg        RegWrite,   // 1 = save into a register
    output reg        WBsel,      // what to save: 0 = ALU result, 1 = memory data
    output reg  [1:0] ALUOp,      // 0 = ADD, 1 = SUB
    output reg        BSel,       // ALU input B: 0 = register rs2, 1 = immediate
    output reg        MemWrite    // 1 = write into data memory
);
    // Opcodes (first byte of the instruction). PLACEHOLDER values:
    // the team has not frozen the real encoding yet.
    localparam OP_NOP = 8'h00;
    localparam OP_ADD = 8'h01;
    localparam OP_SUB = 8'h02;
    localparam OP_LD  = 8'h10;
    localparam OP_ST  = 8'h11;

    localparam WB_ALU = 1'b0, WB_MEM = 1'b1;
    localparam B_REG  = 1'b0, B_IMM  = 1'b1;

    always @(*) begin
        // Safe defaults: every write permission OFF.
        // "Every write is guilty until proven needed."
        RegWrite = 0; WBsel = WB_ALU; ALUOp = 2'd0; BSel = B_REG; MemWrite = 0;

        case (opcode)
            //            row of the table
            OP_ADD: begin RegWrite = 1; WBsel = WB_ALU; ALUOp = 2'd0; BSel = B_REG; end
            // TODO (SUB owner): OP_SUB row goes here
            OP_SUB: begin RegWrite = 1; WBsel = WB_ALU; ALUOp = 2'd1; BSel = B_REG; end
            // LD: ALU adds base + offset to make the address, memory data goes to rd
            OP_LD:  begin RegWrite = 1; WBsel = WB_MEM; ALUOp = 2'd0; BSel = B_IMM; end
            // TODO (SW owner): OP_ST row goes here
            default: ; // NOP or unknown: change nothing
        endcase
    end
endmodule
