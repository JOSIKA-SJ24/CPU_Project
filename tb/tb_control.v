// Standalone decoder test: cover all 256 opcodes and verify control signals reset correctly after LD/ST.
`timescale 1ns/1ps                     // Time unit: 1 ns; time precision: 1 ps.
module tb_control;                    // Top-level test module with no external ports.
    reg [7:0] opcode;                 // The testbench drives the instruction opcode.
    wire RegWrite, WBsel, BSel, MemWrite; // Receive the four single-bit control signals.
    wire [3:0] ALUOp;                 // Receive the widened operation selector.
    reg [7:0] expected [0:255];       // Independent control table with an 8-bit expected output for each opcode.
    integer i, tests, errors;         // Loop index, check count and failure count.
    control dut (.opcode(opcode), .RegWrite(RegWrite), .WBsel(WBsel),
                 .ALUOp(ALUOp), .BSel(BSel), .MemWrite(MemWrite)); // Connect the controller under test.

    task check_controls;              // Reusable control signal check task.
        input [7:0] test_opcode;      // Instruction opcode to apply for this check.
        input [7:0] expected_controls; // Order: RegWrite, WBsel, ALUOp[3:0], BSel, MemWrite.
        begin                         // Begin the task body.
            opcode = test_opcode;    // Apply the input.
            #1;                      // Wait for combinational decoding to settle.
            tests = tests + 1;       // Count this check.
            if ({RegWrite, WBsel, ALUOp, BSel, MemWrite} !== expected_controls) begin
                errors = errors + 1; // Any mismatched signal, including an unexpected X/Z, is a failure.
                $display("FAIL control: opcode=%h expected=%b got=%b", opcode,
                         expected_controls, {RegWrite, WBsel, ALUOp, BSel, MemWrite}); // Print the complete control word.
            end                       // End of failure branch.
        end                           // End of task body.
    endtask                           // End of check task definition.

    initial begin                     // Run once at the start of simulation.
        tests = 0; errors = 0; opcode = 8'h00; // Initialize counters and input.
        for (i = 0; i < 256; i = i + 1) expected[i] = 8'b00_0000_00; // Unassigned opcodes default to no writes.
        expected[8'h01] = 8'b10_0000_00; // ADD: enable register write, select ALU addition and register operand B.
        expected[8'h02] = 8'b10_0001_00; // SUB: select ALU subtraction.
        expected[8'h03] = 8'b10_0010_00; // AND: select ALU bitwise AND.
        expected[8'h04] = 8'b10_0011_00; // OR: select ALU bitwise OR.
        expected[8'h05] = 8'b10_0100_00; // XOR: select ALU bitwise XOR.
        expected[8'h06] = 8'b10_0101_00; // NOT: select ALU bitwise complement.
        expected[8'h07] = 8'b10_0110_00; // SLL: logical left shift.
        expected[8'h08] = 8'b10_0111_00; // SRL: logical right shift.
        expected[8'h09] = 8'b10_1000_00; // SRA: bit 3 of ALUOp must be preserved.
        expected[8'h0A] = 8'b10_0000_10; // ADDI: select immediate operand B while keeping ALU writeback.
        expected[8'h10] = 8'b11_0000_10; // LD: write back memory data and calculate the address in the ALU.
        expected[8'h11] = 8'b00_0000_11; // ST: write only memory, using base plus immediate for the address.
        for (i = 0; i < 256; i = i + 1) begin // Check every opcode after both ST and LD.
            check_controls(8'h11, expected[8'h11]); // First set MemWrite to 1.
            check_controls(i[7:0], expected[i]);    // Verify that the current instruction restores the correct write permissions.
            check_controls(8'h10, expected[8'h10]); // Then set WBsel and BSel to 1.
            check_controls(i[7:0], expected[i]);    // Verify that writeback source and operand B switch correctly.
        end                            // 256 x 4 = 1024 checks with known opcodes.
        check_controls(8'hxx, 8'b00_0000_00); // An unknown opcode has no write side effects.
        check_controls(8'hzz, 8'b00_0000_00); // A high-impedance opcode has no write side effects.
        if (errors == 0) $display("PASS: control %0d checks, 0 errors.", tests); // Success summary.
        else $display("FAIL: control %0d errors / %0d checks.", errors, tests); // Failure summary.
        $stop;                         // Pause to preserve results; the script reads errors to determine success.
    end                                // End of the one-time test sequence.
endmodule                              // End of module.
