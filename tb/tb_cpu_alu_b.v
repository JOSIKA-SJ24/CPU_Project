// Part B CPU test using the current asynchronous memory interface; migrate loading of both hex files after merging Part A.
`timescale 1ns/1ps                        // Simulation time unit and precision.
module tb_cpu_alu_b;                      // Separate top-level module, preserving the team's original tb_cpu.
    reg clk = 1'b0, reset = 1'b1;        // Start with the clock low and reset asserted.
    always #5 clk = ~clk;                // Clock period: 10 ns.
    cpu dut (.clk(clk), .reset(reset));  // Instantiate the full CPU to exercise actual decoding and writeback.
    reg [15:0] expected_regs [0:15];     // Expected snapshot of all 16 registers after each instruction commits.
    reg [15:0] expected_mem [0:63];      // Expected snapshot of all 64 memory words after each instruction commits.
    reg done;                           // Flag completion of all planned instructions for the simulation script.
    integer i, tests, errors, commits;   // Initialization index, comparison count, error count and committed instruction count.

    task check_commit;                  // Run to the next commit, then check the complete machine state.
        input expect_reg_write;        // Whether this instruction should write a destination register.
        input [3:0] destination;       // Destination register index; writes to R0 must be discarded.
        input [15:0] register_value;   // Expected writeback value, independent of the ALU under test.
        input expect_mem_write;        // Whether this instruction should perform a store.
        input [5:0] address;           // Expected memory index for the store.
        input [15:0] store_value;      // Expected data to store.
        integer index;                 // Loop index for checking the complete register file and memory.
        begin                          // Begin the task body.
            wait (dut.state === 2'd2); // Wait for COMMIT; the watchdog catches a timeout if it is never reached.
            @(posedge clk);            // Wait for the rising clock edge that performs the writes.
            #1;                        // Wait for nonblocking assignments to complete before reading updated registers.
            commits = commits + 1;     // Count committed instructions; the expected PC also increases by 1.
            if (expect_reg_write && destination != 4'd0)
                expected_regs[destination] = register_value; // Update the expected register snapshot; R0 is always zero.
            if (expect_mem_write) expected_mem[address] = store_value; // Only the specified store may change memory.
            tests = tests + 1;         // Verify that each instruction advances the PC correctly.
            if (dut.pc !== commits[15:0]) begin // Detect an unexpected jump or failure to advance.
                errors = errors + 1;
                $display("FAIL B: commit=%0d pc=%h expected=%h", commits, dut.pc, commits[15:0]);
            end                        // End of PC check.
            tests = tests + 1;         // Verify that the CPU returns to FETCH after commit.
            if (dut.state !== 2'd0) begin
                errors = errors + 1;
                $display("FAIL B: commit=%0d state should return to FETCH", commits);
            end                        // End of state check.
            for (index = 0; index < 16; index = index + 1) begin // Check all registers after every instruction.
                tests = tests + 1;
                if (dut.rf.r[index] !== expected_regs[index]) begin
                    errors = errors + 1;
                    $display("FAIL B: PC=%0d R%0d expected=%h got=%h", commits-1,
                             index, expected_regs[index], dut.rf.r[index]); // Identify unexpected register writes or incorrect results.
                end                    // End of check for this register.
            end                        // End of all register checks.
            for (index = 0; index < 64; index = index + 1) begin // Check memory, including that non-ST instructions leave it unchanged.
                tests = tests + 1;
                if (dut.dmem[index] !== expected_mem[index]) begin
                    errors = errors + 1;
                    $display("FAIL B: PC=%0d DMEM[%0d] expected=%h got=%h", commits-1,
                             index, expected_mem[index], dut.dmem[index]); // Identify an incorrect store address or data value.
                end                    // End of check for this memory word.
            end                        // End of all memory checks.
        end                            // End of commit checks for this instruction.
    endtask                            // End of task definition; call once per instruction.

    initial begin                      // Run the main test sequence once.
        tests = 0; errors = 0; commits = 0; done = 1'b0; // Initialize all counters and completion status.
        for (i = 0; i < 64; i = i + 1) begin // Initialize unused locations to deterministic values.
            dut.imem[i] = 32'd0;       // Fill unused instruction memory with NOPs.
            dut.dmem[i] = 16'hA55A;   // Fill memory with a nonzero sentinel to detect unintended writes.
        end                            // Initialize all 64 program words and data words.
        $readmemh("programs/alu_b_program.hex", dut.imem, 0, 47); // Load 48 test instructions.
        $readmemh("programs/alu_b_data.hex", dut.dmem, 0, 3); // Load four initial operands.
        for (i = 0; i < 64; i = i + 1) expected_mem[i] = dut.dmem[i]; // Save the initial expected memory contents.
        for (i = 0; i < 16; i = i + 1) expected_regs[i] = 16'd0; // All registers should be zero after reset.
        repeat (2) @(posedge clk);     // Give the CPU and register file at least two rising clock edges under reset.
        @(negedge clk); reset = 1'b0; // Release reset on the falling edge to avoid a race with rising-edge sequential logic.
        // Arguments: register write enable, rd, expected value, memory write enable, address, store value.
        check_commit(1'b1, 4'd1, 16'hA5A5, 1'b0, 6'd0, 16'h0000); // PC 00: LD R1, 0(R0): load the first logic test operand.
        check_commit(1'b1, 4'd2, 16'h0FF0, 1'b0, 6'd0, 16'h0000); // PC 01: LD R2, 1(R0): load the second logic test operand.
        check_commit(1'b1, 4'd3, 16'h05A0, 1'b0, 6'd0, 16'h0000); // PC 02: AND R3, R1, R2.
        check_commit(1'b1, 4'd4, 16'hAFF5, 1'b0, 6'd0, 16'h0000); // PC 03: OR R4, R1, R2.
        check_commit(1'b1, 4'd5, 16'hAA55, 1'b0, 6'd0, 16'h0000); // PC 04: XOR R5, R1, R2.
        check_commit(1'b1, 4'd6, 16'h5A5A, 1'b0, 6'd0, 16'h0000); // PC 05: NOT R6, R1: ignore nonzero rs2 and imm12.
        check_commit(1'b1, 4'd7, 16'h0001, 1'b0, 6'd0, 16'h0000); // PC 06: ADDI R7, R0, 1: ignore nonzero rs2.
        check_commit(1'b1, 4'd8, 16'h8001, 1'b0, 6'd0, 16'h0000); // PC 07: LD R8, 2(R0): load a negative bit pattern for shift tests.
        check_commit(1'b1, 4'd9, 16'h0002, 1'b0, 6'd0, 16'h0000); // PC 08: SLL R9, R8, R7: shift left by 1.
        check_commit(1'b1, 4'd10, 16'h4000, 1'b0, 6'd0, 16'h0000); // PC 09: SRL R10, R8, R7: logical right shift by 1.
        check_commit(1'b1, 4'd11, 16'hC000, 1'b0, 6'd0, 16'h0000); // PC 10: SRA R11, R8, R7: arithmetic right shift by 1.
        check_commit(1'b1, 4'd12, 16'h0FFF, 1'b0, 6'd0, 16'h0000); // PC 11: ADDI imm=FFF: must zero-extend to 0FFF.
        check_commit(1'b1, 4'd13, 16'h0800, 1'b0, 6'd0, 16'h0000); // PC 12: ADDI imm=800: must zero-extend to 0800.
        check_commit(1'b1, 4'd14, 16'h1000, 1'b0, 6'd0, 16'h0000); // PC 13: ADDI uses the nonzero base value in R12.
        check_commit(1'b1, 4'd15, 16'h0000, 1'b0, 6'd0, 16'h0000); // PC 14: ADDI imm=0: must not use the value in R2.
        check_commit(1'b1, 4'd3, 16'h8001, 1'b0, 6'd0, 16'h0000); // PC 15: SRA with shift amount 0 preserves the bit pattern.
        check_commit(1'b1, 4'd7, 16'h000F, 1'b0, 6'd0, 16'h0000); // PC 16: ADDI constructs a shift amount of 15.
        check_commit(1'b1, 4'd9, 16'h8000, 1'b0, 6'd0, 16'h0000); // PC 17: SLL shifts left by 15.
        check_commit(1'b1, 4'd10, 16'h0001, 1'b0, 6'd0, 16'h0000); // PC 18: SRL shifts right by 15.
        check_commit(1'b1, 4'd11, 16'hFFFF, 1'b0, 6'd0, 16'h0000); // PC 19: SRA shifts a negative value right by 15.
        check_commit(1'b1, 4'd7, 16'h0010, 1'b0, 6'd0, 16'h0000); // PC 20: ADDI constructs a shift amount of 16.
        check_commit(1'b1, 4'd9, 16'h8001, 1'b0, 6'd0, 16'h0000); // PC 21: SLL: the low 4 bits of 16 are zero.
        check_commit(1'b1, 4'd10, 16'h8001, 1'b0, 6'd0, 16'h0000); // PC 22: SRL: the low 4 bits of 16 are zero.
        check_commit(1'b1, 4'd11, 16'h8001, 1'b0, 6'd0, 16'h0000); // PC 23: SRA: the low 4 bits of 16 are zero.
        check_commit(1'b1, 4'd7, 16'hFFFF, 1'b0, 6'd0, 16'h0000); // PC 24: LD R7, 3(R0): all upper bits of the shift operand are 1.
        check_commit(1'b1, 4'd11, 16'hFFFF, 1'b0, 6'd0, 16'h0000); // PC 25: SRA: use only the low 4 bits of FFFF, giving 15.
        check_commit(1'b1, 4'd10, 16'h0001, 1'b0, 6'd0, 16'h0000); // PC 26: SRL: use only the low 4 bits of FFFF, giving 15.
        check_commit(1'b1, 4'd9, 16'h8000, 1'b0, 6'd0, 16'h0000); // PC 27: SLL: use only the low 4 bits of FFFF, giving 15.
        check_commit(1'b1, 4'd14, 16'h0000, 1'b0, 6'd0, 16'h0000); // PC 28: ADDI: FFFF + 1 wraps to 0000.
        check_commit(1'b1, 4'd15, 16'h17FF, 1'b0, 6'd0, 16'h0000); // PC 29: Original ADD instruction regression: 0FFF + 0800.
        check_commit(1'b1, 4'd15, 16'hE801, 1'b0, 6'd0, 16'h0000); // PC 30: Original SUB instruction regression: 0 - 17FF.
        check_commit(1'b1, 4'd0, 16'hAA55, 1'b0, 6'd0, 16'h0000); // PC 31: XOR attempts to write R0; the register file must ignore the write.
        check_commit(1'b1, 4'd6, 16'h5A5A, 1'b0, 6'd0, 16'h0000); // PC 32: NOT ignores the second operand value of FFFF.
        check_commit(1'b0, 4'd0, 16'h0000, 1'b1, 6'd4, 16'h5A5A); // PC 33: ST R6, 4(R0): save the NOT result.
        check_commit(1'b1, 4'd6, 16'h5A5B, 1'b0, 6'd0, 16'h0000); // PC 34: ADDI immediately after ST: MemWrite must clear.
        check_commit(1'b0, 4'd0, 16'h0000, 1'b1, 6'd5, 16'h5A5B); // PC 35: ST R6, 5(R0): save the ADDI result.
        check_commit(1'b1, 4'd3, 16'h5A5A, 1'b0, 6'd0, 16'h0000); // PC 36: LD R3, 4(R0): read back the earlier store result.
        check_commit(1'b1, 4'd4, 16'h05A0, 1'b0, 6'd0, 16'h0000); // PC 37: AND immediately after LD: WBsel must return to ALU writeback.
        check_commit(1'b0, 4'd4, 16'h0000, 1'b0, 6'd0, 16'h0000); // PC 38: Undefined opcode: no registers or memory may change.
        check_commit(1'b0, 4'd4, 16'h0000, 1'b0, 6'd0, 16'h0000); // PC 39: NOP must not write even when other fields are nonzero.
        check_commit(1'b1, 4'd0, 16'h0FFF, 1'b0, 6'd0, 16'h0000); // PC 40: ADDI attempts to write R0; R0 must remain zero.
        check_commit(1'b1, 4'd5, 16'hA5A5, 1'b0, 6'd0, 16'h0000); // PC 41: ADDI with zero preserves the source register bit pattern.
        check_commit(1'b1, 4'd5, 16'h07FF, 1'b0, 6'd0, 16'h0000); // PC 42: ADDI boundary case imm=7FF.
        check_commit(1'b1, 4'd5, 16'h0000, 1'b0, 6'd0, 16'h0000); // PC 43: ADDI boundary case imm=000.
        check_commit(1'b1, 4'd5, 16'hFFFF, 1'b0, 6'd0, 16'h0000); // PC 44: NOT R5, R0: complementing all zeros produces all ones.
        check_commit(1'b1, 4'd5, 16'hFFFF, 1'b0, 6'd0, 16'h0000); // PC 45: SRA uses the same source and destination register.
        check_commit(1'b1, 4'd5, 16'h0001, 1'b0, 6'd0, 16'h0000); // PC 46: SRL uses the result written back by the previous instruction.
        check_commit(1'b1, 4'd5, 16'h0000, 1'b0, 6'd0, 16'h0000); // PC 47: AND with R0 produces zero.
        done = 1'b1;                   // Mark completion only after checking every instruction.
        if (errors == 0) $display("PASS: B CPU %0d instructions, %0d checks, 0 errors.", commits, tests);
        else $display("FAIL: B CPU %0d errors / %0d checks.", errors, tests);
        $stop;                         // Pause so the script can read errors and done.
    end                                // End of main sequence.

    initial begin                      // Independent simulation timeout watchdog.
        #10000;                        // Normal execution takes about 1.5 us; 10 us is enough to detect a stall.
        if (!done) begin               // Report failure if incomplete, preventing an endless wait.
            errors = errors + 1;
            $display("FAIL: B CPU timeout after %0d commits.", commits);
            $stop;                     // Leave done=0 so the script cannot treat a timeout as a pass.
        end                            // End of timeout failure branch.
    end                                // End of watchdog sequence.
endmodule                              // End of CPU testbench.
