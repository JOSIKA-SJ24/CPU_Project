// Standalone decoder test: cover all 256 opcodes and verify control signals reset correctly after LD/ST.
`timescale 1ns/1ps                     // Time unit: 1 ns; time precision: 1 ps.
module tb_control;                    // Top-level test module with no external ports.
    reg [7:0] opcode;                 // The testbench drives the instruction opcode.
    wire RegWrite, BSel, MemWrite;    // Single-bit control signals.
    wire [1:0] WBsel;                 // Part C: writeback select widened to 2 bits.
    wire ACCWrite, ACCClear;          // Part C: accumulator controls.
    wire [3:0] ALUOp;                 // Receive the widened operation selector.
    reg [10:0] expected [0:255];      // Independent control table with an 11-bit expected output for each opcode.
    integer i, tests, errors;         // Loop index, check count and failure count.
    control dut (.opcode(opcode), .RegWrite(RegWrite), .WBsel(WBsel),
                 .ALUOp(ALUOp), .BSel(BSel), .MemWrite(MemWrite),
                 .ACCWrite(ACCWrite), .ACCClear(ACCClear)); // Connect the controller under test.

    task check_controls;              // Reusable control signal check task.
        input [7:0] test_opcode;      // Instruction opcode to apply for this check.
        input [10:0] expected_controls; // Order: RegWrite, WBsel[1:0], ALUOp[3:0], BSel, MemWrite, ACCWrite, ACCClear.
        begin                         // Begin the task body.
            opcode = test_opcode;    // Apply the input.
            #1;                      // Wait for combinational decoding to settle.
            tests = tests + 1;       // Count this check.
            if ({RegWrite, WBsel, ALUOp, BSel, MemWrite, ACCWrite, ACCClear} !== expected_controls) begin
                errors = errors + 1; // Any mismatched signal, including an unexpected X/Z, is a failure.
                $display("FAIL control: opcode=%h expected=%b got=%b", opcode,
                         expected_controls, {RegWrite, WBsel, ALUOp, BSel, MemWrite, ACCWrite, ACCClear}); // Print the complete control word.
            end                       // End of failure branch.
        end                           // End of task body.
    endtask                           // End of check task definition.

    initial begin                     // Run once at the start of simulation.
        tests = 0; errors = 0; opcode = 8'h00; // Initialize counters and input.
        for (i = 0; i < 256; i = i + 1) expected[i] = 11'b0_00_0000_00_00; // Unassigned opcodes default to no writes.
        expected[8'h01] = 11'b1_00_0000_00_00; // ADD: enable register write, select ALU addition and register operand B.
        expected[8'h02] = 11'b1_00_0001_00_00; // SUB: select ALU subtraction.
        expected[8'h03] = 11'b1_00_0010_00_00; // AND: select ALU bitwise AND.
        expected[8'h04] = 11'b1_00_0011_00_00; // OR: select ALU bitwise OR.
        expected[8'h05] = 11'b1_00_0100_00_00; // XOR: select ALU bitwise XOR.
        expected[8'h06] = 11'b1_00_0101_00_00; // NOT: select ALU bitwise complement.
        expected[8'h07] = 11'b1_00_0110_00_00; // SLL: logical left shift.
        expected[8'h08] = 11'b1_00_0111_00_00; // SRL: logical right shift.
        expected[8'h09] = 11'b1_00_1000_00_00; // SRA: bit 3 of ALUOp must be preserved.
        expected[8'h0A] = 11'b1_00_0000_10_00; // ADDI: select immediate operand B while keeping ALU writeback.
        expected[8'h10] = 11'b1_01_0000_10_00; // LD: write back memory data and calculate the address in the ALU.
        expected[8'h11] = 11'b0_00_0000_11_00; // ST: write only memory, using base plus immediate for the address.
        expected[8'h0B] = 11'b1_10_0000_00_00; // Part C LDI: write the immediate to rd.
        expected[8'h0C] = 11'b0_00_0000_00_01; // Part C CLRACC: clear ACC only.
        expected[8'h0D] = 11'b0_00_0000_00_10; // Part C MAC: write ACC only.
        expected[8'h0E] = 11'b1_11_0000_00_00; // Part C ACCOUT: write the ACC slice to rd.
        for (i = 0; i < 256; i = i + 1) begin // Check every opcode after both ST and LD.
            check_controls(8'h11, expected[8'h11]); // First set MemWrite to 1.
            check_controls(i[7:0], expected[i]);    // Verify that the current instruction restores the correct write permissions.
            check_controls(8'h10, expected[8'h10]); // Then set WBsel and BSel to 1.
            check_controls(i[7:0], expected[i]);    // Verify that writeback source and operand B switch correctly.
        end                            // 256 x 4 = 1024 checks with known opcodes.
        check_controls(8'hxx, 11'b0_00_0000_00_00); // An unknown opcode has no write side effects.
        check_controls(8'hzz, 11'b0_00_0000_00_00); // A high-impedance opcode has no write side effects.
        if (errors == 0) $display("PASS: control %0d checks, 0 errors.", tests); // Success summary.
        else $display("FAIL: control %0d errors / %0d checks.", errors, tests); // Failure summary.
        $stop;                         // Pause to preserve results; the script reads errors to determine success.
    end                                // End of the one-time test sequence.
endmodule                              // End of module.
