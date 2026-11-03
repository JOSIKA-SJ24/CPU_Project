// =============================================================
// Testbench: everything that is NOT hardware.
// (Prof: "the testbench is everything you can't synthesize.")
// It makes the clock, loads the program and data, prints what
// happens at every COMMIT, then checks the final memory image.
// =============================================================
`timescale 1ns/1ps
module tb_cpu;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;                 // 10 ns clock

    cpu dut (.clk(clk), .reset(reset));   // dut = "device under test"

    integer i, errors;
    initial begin
        $dumpfile("cpu.vcd");             // waveform file for GTKWave
        $dumpvars(0, tb_cpu);

        for (i = 0; i < 64; i = i + 1) begin dut.imem[i] = 32'd0; dut.dmem[i] = 16'd0; end
        $readmemh("program.hex", dut.imem, 0, 2);
        $readmemh("data.hex",    dut.dmem, 0, 3);

        repeat (2) @(posedge clk);
        reset = 0;

        // 3 instructions x 3 steps each = 9 clock cycles
        repeat (9) @(posedge clk);
        #1;

        $display("\nRegisters after the program:");
        $display("  R1 = %0d, R2 = %0d, R3 = %0d", dut.rf.r[1], dut.rf.r[2], dut.rf.r[3]);

        errors = 0;
        if (dut.rf.r[1] !== 16'd5)  begin $display("FAIL: R1 should be 5 (loaded from DMEM[0])"); errors = errors + 1; end
        if (dut.rf.r[2] !== 16'd7)  begin $display("FAIL: R2 should be 7 (loaded from DMEM[1])"); errors = errors + 1; end
        if (dut.rf.r[3] !== 16'd12) begin $display("FAIL: R3 should be 12 (5 + 7)");           errors = errors + 1; end
        if (errors == 0) $display("\nPASS: LD and ADD work.");
        $stop;   // pauses ModelSim instead of asking to quit
    end

    // Print one line every time an instruction commits.
    always @(posedge clk) begin
        if (!reset && dut.state == 2'd2) begin
            case (dut.opcode)
              8'h10: $display("PC=%0d  LD  R%0d, %0d(R%0d)   -> R%0d = %0d (read from DMEM[%0d])",
                       dut.pc, dut.rd, dut.ir[11:0], dut.rs1, dut.rd, dut.WB_DATA16, dut.addr16);
              8'h01: $display("PC=%0d  ADD R%0d, R%0d, R%0d  -> %0d + %0d = %0d",
                       dut.pc, dut.rd, dut.rs1, dut.rs2, dut.A16, dut.B16, dut.WB_DATA16);
              8'h02: $display("PC=%0d  SUB R%0d, R%0d, R%0d  -> %0d - %0d = %0d",
                       dut.pc, dut.rd, dut.rs1, dut.rs2, dut.A16, dut.B16, dut.WB_DATA16);
              8'h11: $display("PC=%0d  ST  R%0d, %0d(R%0d)   -> DMEM[%0d] = %0d",
                       dut.pc, dut.rs2, dut.ir[11:0], dut.rs1, dut.addr16, dut.B16);
              default: $display("PC=%0d  NOP", dut.pc);
            endcase
        end
    end
endmodule
