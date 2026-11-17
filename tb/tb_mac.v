// Unit test for mac.v (Part C): checks ACC after every operation against a
// reference model computed in the testbench (signed 16x16 product,
// sign-extended to 48 bits, added modulo 2^48).
`timescale 1ns/1ps
module tb_mac;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;

    reg  [15:0] a, b;
    reg         acc_write, acc_clear;
    wire [47:0] acc;
    reg  [47:0] model;            // what ACC should be
    integer i, tests, errors;

    mac dut (.clk(clk), .reset(reset), .a(a), .b(b),
             .acc_write(acc_write), .acc_clear(acc_clear), .acc(acc));

    // Apply one operation for one clock edge, update the model, compare.
    task step(input [15:0] ta, input [15:0] tb, input tw, input tc);
        reg signed [31:0] p;
        begin
            @(negedge clk);
            a = ta; b = tb; acc_write = tw; acc_clear = tc;
            p = $signed(ta) * $signed(tb);
            if (tc)      model = 48'd0;
            else if (tw) model = model + {{16{p[31]}}, p};
            @(posedge clk); #1;
            tests = tests + 1;
            if (acc !== model) begin
                errors = errors + 1;
                $display("FAIL mac: a=%h b=%h write=%b clear=%b expected=%h got=%h", ta, tb, tw, tc, model, acc);
            end
        end
    endtask

    initial begin
        tests = 0; errors = 0; model = 48'd0;
        a = 0; b = 0; acc_write = 0; acc_clear = 0;
        repeat (2) @(posedge clk); #1;
        if (acc !== 48'd0) begin errors = errors + 1; $display("FAIL mac: ACC not 0 after reset"); end
        reset = 0;

        // ISA draft example: ACC = 10, R1 = 3, R2 = -2  ->  ACC = 4
        step(16'd10, 16'd1, 1, 0);
        step(16'd3, 16'hFFFE, 1, 0);
        if (acc !== 48'd4) begin errors = errors + 1; $display("FAIL mac: ISA example should give 4"); end

        step(16'h1234, 16'h5678, 0, 0);   // no write: ACC must not change
        step(16'h1234, 16'h5678, 0, 1);   // CLRACC
        step(16'h1234, 16'h5678, 1, 1);   // clear wins over write
        step(16'h8000, 16'h8000, 1, 0);   // (-32768)^2 = +2^30, largest product
        step(16'h8000, 16'h7FFF, 1, 0);   // most negative product
        step(16'hFFFF, 16'hFFFF, 1, 0);   // (-1)*(-1) = +1
        step(16'd0,    16'hFFFF, 1, 0);   // multiply by zero

        // Many products of the same sign: grows past 32 bits (needs the headroom)
        for (i = 0; i < 300; i = i + 1) step(16'h8000, 16'h8000, 1, 0);
        // Negative accumulation from zero: ACC goes negative (upper bits all 1)
        step(16'd0, 16'd0, 0, 1);
        for (i = 0; i < 300; i = i + 1) step(16'h8000, 16'h7FFF, 1, 0);

        // Random operations
        for (i = 0; i < 2000; i = i + 1)
            step($random, $random, ($random % 4) != 0, ($random % 50) == 0);

        // Reset clears ACC
        @(negedge clk); reset = 1; acc_write = 0; acc_clear = 0;
        @(posedge clk); #1; tests = tests + 1;
        if (acc !== 48'd0) begin errors = errors + 1; $display("FAIL mac: reset should clear ACC"); end

        if (errors == 0) $display("PASS: mac %0d checks, 0 errors.", tests);
        else             $display("FAIL: mac %0d errors / %0d checks.", errors, tests);
        $stop;
    end
endmodule
