`timescale 1ns/1ps
module tb_imem;
    reg clk = 0;
    always #5 clk = ~clk;

    reg  [5:0]  read_address;
    wire [31:0] q;

    imem_m10k u_imem (.q(q), .read_address(read_address), .clk(clk));

    integer k;
    initial begin
        for (k = 0; k < 6; k = k + 1) begin
            read_address = k;
            @(posedge clk); #1;
            $display("imem[%0d] = %h", k, q);
        end
        $stop;
    end
endmodule
