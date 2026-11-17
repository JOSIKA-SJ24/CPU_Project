// CPU integration test for Part C (LDI, CLRACC, MAC, ACCOUT).
// The CPU's only inputs are clk and reset. The program is chosen by
// overriding the instruction memory's INIT_FILE parameter (simulation only).
`timescale 1ns/1ps
module tb_cpu_dsp_c;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;

    cpu dut (.clk(clk), .reset(reset));
    defparam dut.u_imem.INIT_FILE = "programs/dsp_c_program.hex";
    defparam dut.u_dmem.INIT_FILE = "programs/data.hex";

    localparam N_INSTR = 25;           // instructions in dsp_c_program.hex
    integer errors;

    task check_reg(input [3:0] r, input [15:0] expected, input [8*40-1:0] why);
        if (dut.rf.r[r] !== expected) begin
            errors = errors + 1;
            $display("FAIL C: R%0d = %h, expected %h (%0s)", r, dut.rf.r[r], expected, why);
        end
    endtask

    // Print one line per committed instruction (COMMIT = state 3).
    always @(posedge clk)
        if (!reset && dut.state == 2'd3)
            $display("PC=%0d  ir=%h  ACC=%h", dut.pc, dut.ir, dut.acc48);

    initial begin
        errors = 0;
        repeat (2) @(posedge clk);
        reset = 0;
        repeat (N_INSTR * 4) @(posedge clk);   // 4 cycles per instruction
        #1;

        if (dut.pc !== N_INSTR) begin errors = errors + 1; $display("FAIL C: PC = %0d, expected %0d", dut.pc, N_INSTR); end
        if (dut.acc48 !== 48'hFFFF_FFFF_FFFA) begin errors = errors + 1; $display("FAIL C: ACC = %h, expected FFFFFFFFFFFA (-6)", dut.acc48); end

        check_reg(0,  16'h0000, "LDI/ACCOUT to R0 must be ignored");
        check_reg(1,  16'h0003, "LDI R1, 3");
        check_reg(2,  16'hFFFE, "LDI full 16-bit immediate");
        check_reg(3,  16'h000A, "LDI R3, 10");
        check_reg(4,  16'h0005, "LD after Part C instructions");
        check_reg(5,  16'h0004, "ISA example: 10 + 3*(-2)");
        check_reg(6,  16'h8000, "LDI R6, 0x8000");
        check_reg(7,  16'h0004, "ACCOUT sel 0 (low)");
        check_reg(8,  16'h4000, "ACCOUT sel 1 (middle)");
        check_reg(9,  16'h0000, "ACCOUT sel 2 (high)");
        check_reg(10, 16'h7FFF, "LDI R10, 0x7FFF");
        check_reg(11, 16'h8004, "MAC with a negative product");
        check_reg(12, 16'h0000, "ACCOUT sel 2 after positive sum");
        check_reg(13, 16'hFFFF, "negative ACC: high slice is sign bits");
        check_reg(14, 16'hFFFA, "negative ACC: low slice");
        check_reg(15, 16'h0007, "ADD after ACCOUT (ALU writeback)");

        // MAC/CLRACC must never write data memory
        if (dut.u_dmem.mem[0] !== 16'd5 || dut.u_dmem.mem[1] !== 16'd7) begin
            errors = errors + 1; $display("FAIL C: data memory changed");
        end

        if (errors == 0) $display("\nPASS: Part C (LDI, CLRACC, MAC, ACCOUT), %0d instructions.", N_INSTR);
        else             $display("\nFAIL: Part C, %0d errors.", errors);
        $stop;
    end
endmodule
