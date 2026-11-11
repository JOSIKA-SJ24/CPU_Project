// Instruction decoder: convert the 8-bit opcode into datapath control signals.
// This module selects the action; COMMIT in cpu.v determines when writes occur.
// New opcodes use the agreed provisional mapping; update them here when the team freezes the ISA.
module control (                         // Define the control module and its ports.
    input  wire [7:0] opcode,             // Instruction bits ir[31:24], distinct from the internal ALUOp.
    output reg        RegWrite,           // 1 enables a destination register write; the CPU also gates it with commit.
    output reg        WBsel,              // 0 selects the ALU result for writeback; 1 selects data memory output.
    output reg  [3:0] ALUOp,              // Widened to 4 bits to match alu.v and cpu.v.
    output reg        BSel,               // 0 selects R[rs2] as operand B; 1 selects the zero-extended imm12.
    output reg        MemWrite            // 1 enables a store to memory; the CPU performs it during COMMIT.
);                                       // End of port list.
    localparam [7:0] OP_NOP  = 8'h00;     // No operation: write neither registers nor memory.
    localparam [7:0] OP_ADD  = 8'h01;     // Existing register addition.
    localparam [7:0] OP_SUB  = 8'h02;     // Existing register subtraction.
    localparam [7:0] OP_AND  = 8'h03;     // New bitwise AND; opcodes 03 through 0A are provisional.
    localparam [7:0] OP_OR   = 8'h04;     // New bitwise OR.
    localparam [7:0] OP_XOR  = 8'h05;     // New bitwise XOR.
    localparam [7:0] OP_NOT  = 8'h06;     // New bitwise NOT; use only rs1 and ignore rs2 and imm12.
    localparam [7:0] OP_SLL  = 8'h07;     // New logical left shift; the shift amount is R[rs2][3:0].
    localparam [7:0] OP_SRL  = 8'h08;     // New logical right shift.
    localparam [7:0] OP_SRA  = 8'h09;     // New arithmetic right shift.
    localparam [7:0] OP_ADDI = 8'h0A;     // New immediate addition; zero-extend imm12 and ignore rs2.
    localparam [7:0] OP_LD   = 8'h10;     // Retain the existing load instruction encoding.
    localparam [7:0] OP_ST   = 8'h11;     // Retain the existing store instruction encoding.

    localparam [3:0] ALU_ADD = 4'd0;      // Internal operation encodings must match alu.v.
    localparam [3:0] ALU_SUB = 4'd1;      // Subtraction.
    localparam [3:0] ALU_AND = 4'd2;      // Bitwise AND.
    localparam [3:0] ALU_OR  = 4'd3;      // Bitwise OR.
    localparam [3:0] ALU_XOR = 4'd4;      // Bitwise XOR.
    localparam [3:0] ALU_NOT = 4'd5;      // Bitwise NOT.
    localparam [3:0] ALU_SLL = 4'd6;      // Logical left shift.
    localparam [3:0] ALU_SRL = 4'd7;      // Logical right shift.
    localparam [3:0] ALU_SRA = 4'd8;      // Arithmetic right shift, using the highest bit of ALUOp.
    localparam WB_ALU = 1'b0, WB_MEM = 1'b1; // The two writeback source selections.
    localparam B_REG  = 1'b0, B_IMM  = 1'b1; // The two ALU operand B selections.

    always @(*) begin                    // Decode whenever opcode changes; combinational logic needs no clock.
        RegWrite = 1'b0;                 // Disable register writes by default so previous instruction controls cannot persist.
        WBsel = WB_ALU;                  // Default writeback source is the ALU.
        ALUOp = ALU_ADD;                 // Default operation is addition, with no write permission by default.
        BSel = B_REG;                    // Default second operand is a register value.
        MemWrite = 1'b0;                 // Disable memory writes by default.
        case (opcode)                   // Each entry represents one CPU instruction in the control table.
            OP_NOP: ;                   // Keep all defaults; NOP has no write side effects.
            OP_ADD:  begin RegWrite = 1'b1; ALUOp = ALU_ADD; end // Add register values and write back the result.
            OP_SUB:  begin RegWrite = 1'b1; ALUOp = ALU_SUB; end // Subtract register values and write back the result.
            OP_AND:  begin RegWrite = 1'b1; ALUOp = ALU_AND; end // Write the AND result to rd.
            OP_OR:   begin RegWrite = 1'b1; ALUOp = ALU_OR;  end // Write the OR result to rd.
            OP_XOR:  begin RegWrite = 1'b1; ALUOp = ALU_XOR; end // Write the XOR result to rd.
            OP_NOT:  begin RegWrite = 1'b1; ALUOp = ALU_NOT; end // Complement rs1 and write the result to rd.
            OP_SLL:  begin RegWrite = 1'b1; ALUOp = ALU_SLL; end // Write the left shift result to rd.
            OP_SRL:  begin RegWrite = 1'b1; ALUOp = ALU_SRL; end // Write the logical right shift result to rd.
            OP_SRA:  begin RegWrite = 1'b1; ALUOp = ALU_SRA; end // Write the arithmetic right shift result to rd.
            OP_ADDI: begin RegWrite = 1'b1; ALUOp = ALU_ADD; BSel = B_IMM; end // Add the immediate value.
            OP_LD: begin                // LD: calculate the address in the ALU and select memory data for writeback.
                RegWrite = 1'b1; WBsel = WB_MEM; ALUOp = ALU_ADD; BSel = B_IMM;
            end                        // MemWrite remains 0; memory is not written.
            OP_ST: begin                // ST: calculate the address and write memory, without writing a destination register.
                MemWrite = 1'b1; ALUOp = ALU_ADD; BSel = B_IMM;
            end                        // RegWrite remains 0; WBsel does not affect writeback here.
            default: ;                 // Undefined opcodes or those containing X/Z keep defaults and have no write side effects.
        endcase                        // End of instruction selection.
    end                                // End of combinational decoder; every output has a default assignment.
endmodule                              // End of control module.
