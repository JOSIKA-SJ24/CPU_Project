// Standalone ALU testbench: generate inputs and compare results automatically; simulation only.
`timescale 1ns/1ps                  // Time unit: 1 ns; time precision: 1 ps.
module tb_alu;                     // Top-level test module with no external ports.
    reg  [15:0] a, b;              // Drive both operands through procedural assignments in the testbench.
    reg  [3:0]  op;                // Drive the operation selection signal.
    wire [15:0] y;                // Receive the output from the ALU under test.
    integer tests, errors;         // Count checks and failures for the simulation script to read.
    integer i, seed;               // Loop index and seed for repeatable pseudorandom tests.
    integer ref_a, ref_b;          // 32-bit reference operands, both ranging from 0 to 65535.
    integer expected_add, expected_sub; // Compute reference results using wide integers and modulo arithmetic.
    integer operation, amount;    // Iterate over new operations and all 16 effective shift amounts.
    reg [15:0] random_a, random_b; // Store the low 16 bits of each random input pair.

    alu dut (                     // Instantiate the ALU; dut means device under test.
        .a(a),                    // The name on the left is an ALU port; the parentheses contain a testbench signal.
        .b(b),                    // Connect local b to the ALU b port.
        .op(op),                  // Connect local op to the ALU op port.
        .y(y)                     // Connect the ALU output to local y.
    );                            // End of module instantiation.

    // Independent model: evaluate logic bit by bit and shifts by repeated multiplication/division by 2, rather than copying RTL expressions.
    function [15:0] reference_result;
        input [3:0] test_op;       // Operation codes 2 through 8 supported by this reference model.
        input [15:0] test_a;       // Known 16-bit input A.
        input [15:0] test_b;       // Known 16-bit input B.
        integer bit_index, shift_index; // Counters for bit iteration and individual shift steps.
        integer value, shift_count; // Wide intermediate value and shift amount from the low 4 bits.
        reg [15:0] logic_result;   // Build the logic reference result one bit at a time.
        begin                     // Begin the function body; it contains no timing delays.
            logic_result = 16'd0; // Initialize to zero so every branch has a defined result.
            value = {16'd0, test_a}; // Zero-extend to a nonnegative 32-bit integer.
            shift_count = {28'd0, test_b[3:0]}; // The upper 12 bits do not contribute to the shift amount.
            for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
                case (test_op)    // Process one bit at a time; random inputs contain only known 0/1 values.
                    4'd2: logic_result[bit_index] = (test_a[bit_index] == 1'b1) && (test_b[bit_index] == 1'b1); // AND truth table.
                    4'd3: logic_result[bit_index] = (test_a[bit_index] == 1'b1) || (test_b[bit_index] == 1'b1); // OR truth table.
                    4'd4: logic_result[bit_index] = (test_a[bit_index] != test_b[bit_index]); // XOR truth table.
                    4'd5: logic_result[bit_index] = (test_a[bit_index] == 1'b0); // NOT truth table.
                    default: logic_result[bit_index] = 1'b0; // Shift operations do not use logic_result.
                endcase           // End of processing for this bit.
            end                   // End of processing for all 16 bits.
            case (test_op)        // Select the bitwise logic result or the integer shift model.
                4'd2, 4'd3, 4'd4, 4'd5: reference_result = logic_result; // Return the logic result.
                4'd6, 4'd7, 4'd8: begin // Model all three shifts one bit at a time.
                    for (shift_index = 0; shift_index < shift_count; shift_index = shift_index + 1) begin
                        if (test_op == 4'd6) value = (value * 2) % 65536; // Left shift is multiplication by 2 followed by truncation.
                        else if (test_op == 4'd7) value = value / 2; // Logical right shift is division of a nonnegative integer by 2.
                        else value = value / 2 + ((value >= 32768) ? 32768 : 0); // Restore the top bit when the previous top bit was 1.
                    end           // Complete the required number of shift steps.
                    reference_result = value[15:0]; // Return the current 16-bit result.
                end               // End of shift reference branch.
                default: reference_result = 16'd0; // Other operations are not modeled by this function.
            endcase               // End of reference operation selection.
        end                       // End of reference function body.
    endfunction                   // The function returns its result through the variable with the same name.

    // A task provides reusable test steps; the #1 delay prevents using a Verilog function here.
    task check_case;
        input [3:0] test_op;       // Operation code for this test case.
        input [15:0] test_a;       // First operand for this test case.
        input [15:0] test_b;       // Second operand for this test case.
        input [15:0] expected;     // Expected 16-bit result for this test case.
        begin                     // Begin the task body.
            a = test_a;           // Apply the stimulus to ALU input A.
            b = test_b;           // Apply the stimulus to ALU input B.
            op = test_op;         // Select the operation for this test case.
            #1;                  // Wait 1 ns for combinational simulation events to settle before checking.
            tests = tests + 1;    // Count one check per call.
            if (y !== expected) begin // Four-state inequality also detects unexpected X/Z output values.
                errors = errors + 1;  // Record a failure and continue collecting further errors.
                $display("FAIL #%0d: op=%b a=%h b=%h expected=%h got=%h",
                         tests, op, a, b, expected, y); // Print the failing check number, inputs and results.
            end                   // End of failure handling.
        end                       // End of task body.
    endtask                       // End of test task definition.

    initial begin                 // Run this initial block once at the start of simulation.
        tests = 0;                // Initialize the check count to zero.
        errors = 0;               // Initialize the error count to zero.
        seed = 32'h1357_2468;      // Fixed seed allows repeatable tests on the same simulator.
        a = 16'd0;                // Initialize input A to avoid meaningless startup unknowns.
        b = 16'd0;                // Initialize the second operand.
        op = 4'd0;                // Select addition initially.

        // Argument order: op, a, b, expected. Start with manually calculated boundary cases.
        check_case(4'd0, 16'h0000, 16'h0000, 16'h0000); // 0 + 0 = 0.
        check_case(4'd0, 16'h0005, 16'h0007, 16'h000C); // 5 + 7 = 12.
        check_case(4'd0, 16'hFFFF, 16'h0001, 16'h0000); // Unsigned addition overflow wraps to zero.
        check_case(4'd0, 16'h7FFF, 16'h0001, 16'h8000); // Overflow at the upper signed positive boundary.
        check_case(4'd0, 16'h8000, 16'h8000, 16'h0000); // Adding two top bits produces a carry that is truncated.
        check_case(4'd0, 16'hFFFF, 16'hFFFF, 16'hFFFE); // Add two maximum unsigned values.
        check_case(4'd0, 16'hAAAA, 16'h5555, 16'hFFFF); // Add complementary alternating bit patterns.
        check_case(4'd0, 16'h0000, 16'h0FFF, 16'h0FFF); // Zero base address plus the maximum 12-bit offset.
        check_case(4'd0, 16'h0020, 16'h0005, 16'h0025); // Nonzero base address plus offset for LD/ST.
        check_case(4'd0, 16'hFFF0, 16'h0020, 16'h0010); // Address addition also wraps at 16 bits.

        check_case(4'd1, 16'h0007, 16'h0005, 16'h0002); // 7 - 5 = 2.
        check_case(4'd1, 16'h0005, 16'h0007, 16'hFFFE); // 5 - 7 produces the two's complement bit pattern for a negative result.
        check_case(4'd1, 16'h0000, 16'h0001, 16'hFFFF); // 0 - 1 = FFFF.
        check_case(4'd1, 16'h1234, 16'h1234, 16'h0000); // Subtracting identical values produces zero.
        check_case(4'd1, 16'h8000, 16'h0001, 16'h7FFF); // Overflow at the lower signed negative boundary.
        check_case(4'd1, 16'h7FFF, 16'hFFFF, 16'h8000); // Low 16 bits of 32767 - (-1).
        check_case(4'd1, 16'hFFFF, 16'h0000, 16'hFFFF); // Subtracting zero preserves the input bit pattern.
        check_case(4'd1, 16'h0000, 16'hFFFF, 16'h0001); // 0 - 65535 wraps modulo 65536.

        // Change only one input at a time to verify the always @(*) sensitivity includes every input.
        check_case(4'd0, 16'd9, 16'd3, 16'd12); // Establish the initial inputs.
        check_case(4'd1, 16'd9, 16'd3, 16'd6);  // Change only op; the result should change from 12 to 6.
        check_case(4'd1, 16'd10, 16'd3, 16'd7); // Change only a; the result should become 7.
        check_case(4'd1, 16'd10, 16'd4, 16'd6); // Change only b; the result should become 6.

        // Unused codes and unknown selectors take the default branch; X/Z tests describe simulation behavior only.
        check_case(4'b1001, 16'hFFFF, 16'h1234, 16'h0000); // Unused operation code 9.
        check_case(4'b1111, 16'hFFFF, 16'h1234, 16'h0000); // Unused operation code 15.
        check_case(4'bx000, 16'hFFFF, 16'h1234, 16'h0000); // The highest bit of op is unknown.
        check_case(4'b000x, 16'hFFFF, 16'h1234, 16'h0000); // The lowest bit of op is unknown.
        check_case(4'bz001, 16'hFFFF, 16'h1234, 16'h0000); // op contains a high-impedance Z value.
        check_case(4'bzzzz, 16'hFFFF, 16'h1234, 16'h0000); // All four bits of op are Z.
        check_case(4'd0, 16'h0005, 16'h0007, 16'h000C); // Recover normal addition after an invalid selector.
        check_case(4'd0, 16'hxxxx, 16'h0001, 16'hxxxx); // Valid addition with an unknown operand.
        check_case(4'd1, 16'h0001, 16'hzzzz, 16'hxxxx); // Valid subtraction with a high-impedance operand.
        check_case(4'd1, 16'h0007, 16'h0005, 16'h0002); // Restoring known inputs produces 2 again.

        // Part B bitwise logic: use distinct patterns to distinguish bitwise operations from logical truth-value operations.
        check_case(4'd2, 16'hA5A5, 16'h0FF0, 16'h05A0); // AND retains only bits that are 1 in both inputs.
        check_case(4'd3, 16'hA5A5, 16'h0FF0, 16'hAFF5); // OR combines bits that are 1 in either input.
        check_case(4'd4, 16'hA5A5, 16'h0FF0, 16'hAA55); // XOR retains only differing bits.
        check_case(4'd5, 16'hA5A5, 16'h0000, 16'h5A5A); // NOT inverts all 16 bits.
        check_case(4'd5, 16'hA5A5, 16'hFFFF, 16'h5A5A); // Changing B does not affect NOT.
        check_case(4'd5, 16'h0000, 16'hxxxx, 16'hFFFF); // An unknown B must not affect NOT either.
        check_case(4'd5, 16'hFFFF, 16'h0000, 16'h0000); // Complementing all ones produces all zeros.
        check_case(4'd2, 16'h0000, 16'hxxxx, 16'h0000); // Zero AND an unknown bit remains zero.
        check_case(4'd3, 16'hFFFF, 16'hxxxx, 16'hFFFF); // One OR an unknown bit remains one.
        check_case(4'd4, 16'hFFFF, 16'hFFFF, 16'h0000); // XOR of identical patterns produces zero.
        check_case(4'd4, 16'hAAAA, 16'h5555, 16'hFFFF); // XOR of complementary patterns produces all ones.

        check_case(4'd6, 16'h8001, 16'h0001, 16'h0002); // SLL discards the top bit and fills the lowest bit with zero.
        check_case(4'd7, 16'h8001, 16'h0001, 16'h4000); // SRL fills upper bits with zeros.
        check_case(4'd8, 16'h8001, 16'h0001, 16'hC000); // SRA replicates the original sign bit of 1.
        check_case(4'd8, 16'hFFFD, 16'h0001, 16'hFFFE); // Arithmetic right shift of -3 by one bit produces -2.
        check_case(4'd8, 16'h7FFF, 16'h0001, 16'h3FFF); // SRA of a positive value fills upper bits with zeros.
        check_case(4'd6, 16'h8001, 16'h0010, 16'h8001); // The low 4 bits of 16 are zero, so no shift occurs.
        check_case(4'd7, 16'h8001, 16'h0010, 16'h8001); // Check the shift amount mask for SRL as well.
        check_case(4'd8, 16'h8001, 16'h0010, 16'h8001); // Check the shift amount mask for SRA as well.
        check_case(4'd6, 16'h8001, 16'hFFFF, 16'h8000); // The low 4 bits of FFFF specify a shift of 15.
        check_case(4'd7, 16'h8001, 16'hFFFF, 16'h0001); // Logical right shift by 15 bits.
        check_case(4'd8, 16'h8001, 16'hFFFF, 16'hFFFF); // Arithmetic right shift of a negative value by 15 produces all ones.
        check_case(4'd8, 16'h8001, 16'hxxx1, 16'hC000); // Unknown upper 12 bits of B do not affect the shift.
        for (operation = 9; operation < 16; operation = operation + 1) begin // Cover all unassigned ALUOp codes.
            check_case(operation[3:0], 16'hFFFF, 16'h1234, 16'd0); // Each unassigned code must produce zero.
        end                       // End of unused operation code checks.
        for (amount = 0; amount < 16; amount = amount + 1) begin // Cover all effective shift amounts.
            for (operation = 6; operation <= 8; operation = operation + 1) begin // Test all three shift operations.
                check_case(operation[3:0], 16'h0000, amount[15:0], reference_result(operation[3:0], 16'h0000, amount[15:0])); // Zero.
                check_case(operation[3:0], 16'h0001, amount[15:0], reference_result(operation[3:0], 16'h0001, amount[15:0])); // Only the lowest bit is 1.
                check_case(operation[3:0], 16'h7FFF, amount[15:0], reference_result(operation[3:0], 16'h7FFF, amount[15:0])); // Maximum signed positive value.
                check_case(operation[3:0], 16'h8001, amount[15:0], reference_result(operation[3:0], 16'h8001, amount[15:0])); // Negative value with both the highest and lowest bits set.
                check_case(operation[3:0], 16'hFFFF, amount[15:0], reference_result(operation[3:0], 16'hFFFF, amount[15:0])); // All ones.
            end                   // End of the three shift checks for this amount.
        end                       // End of coverage for all shift amounts.

        // Test all nine operations for 512 random input pairs, totaling 4608 random checks.
        for (i = 0; i < 512; i = i + 1) begin // Iterate i from 0 through 511.
            random_a = $random(seed); // Generate a pseudorandom value; assignment to 16 bits retains only the low 16 bits.
            random_b = $random(seed); // Generate the second input; each call updates seed.
            ref_a = {16'd0, random_a}; // Fill the upper 16 bits with zeros to create a nonnegative 32-bit reference value.
            ref_b = {16'd0, random_b}; // Extend B likewise to avoid 16-bit truncation in the reference calculation.
            expected_add = (ref_a + ref_b) % 65536; // Use wide integer modulo arithmetic to retain the low 16 bits.
            expected_sub = (ref_a + 65536 - ref_b) % 65536; // Add the modulus first to avoid a negative remainder.
            check_case(4'd0, random_a, random_b, expected_add[15:0]); // Check ADD.
            check_case(4'd1, random_a, random_b, expected_sub[15:0]); // Check SUB.
            for (operation = 2; operation <= 8; operation = operation + 1) begin // Test the seven new ALU operations.
                check_case(operation[3:0], random_a, random_b, reference_result(operation[3:0], random_a, random_b)); // Compare with the independent reference model.
            end                   // End of checks for the new operations with this random input pair.
        end                       // End of random test loop.

        if (errors == 0)          // Report PASS if every check succeeds.
            $display("PASS: ALU %0d checks, 0 errors.", tests);
        else                      // Report a summary if any check fails.
            $display("FAIL: ALU %0d errors out of %0d checks.", errors, tests);
        $stop;                    // Pause without closing the GUI, preserving waveforms and counters for inspection.
    end                           // End of the one-time test sequence.
endmodule                         // End of testbench.
