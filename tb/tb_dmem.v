`timescale 1ns/1ps
module tb_dmem;
    reg clk = 0;
    always #5 clk = ~clk;

    reg  [15:0] d;
    reg  [5:0]  write_address, read_address;
    reg         we;
    wire [15:0] q;

    dmem_m10k u_dmem (.q(q), .d(d), .write_address(write_address),
                      .read_address(read_address), .we(we), .clk(clk));

    initial begin
        we = 0; d = 0; write_address = 0; read_address = 0;

        // 1) write 0x1234 into address 5
        @(negedge clk);
        write_address = 5; d = 16'h1234; we = 1;
        @(negedge clk);
        we = 0;

        // 2) read address 1
        read_address = 1;
        @(posedge clk); #1;
        $display("t=%0t  read_address = 1             -> q = %h", $time, q);

        // 3) read address 5
        read_address = 5;
        $display("t=%0t  just set read_address = 5   -> q = %h", $time, q);
        @(posedge clk); #1;
        $display("t=%0t  after one clock edge         -> q = %h", $time, q);
        $stop;
    end
endmodule