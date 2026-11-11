// 16-bit Arithmetic Logic Unit (ALU).
// Part B adds AND, OR, XOR, NOT, SLL, SRL and SRA; ADDI/LD/ST reuse ADD.
// Combinational module: no clock, reset or registers that store results.
// Recomputes when inputs change; real hardware has propagation delay.
// Only the low 16 result bits are retained; no carry, borrow or signed overflow flags.


module alu (                        	// Define the alu hardware module and begin its port list.
    input  wire [15:0] a,            	// 16-bit operand A, connected to R[rs1] in the CPU.
    input  wire [15:0] b,            	// 16-bit operand B, selected from a register value or an immediate in the CPU.
    input  wire [3:0]  op,           	// Nine operations require a 4-bit ALUOp; this is separate from the 8-bit instruction opcode.
    output reg  [15:0] y             	// 16-bit result; declared reg because it is assigned inside always.
);                                  

    localparam [3:0] ALU_ADD = 4'd0; 	// 0000: addition, used by ADD, ADDI, LD and ST.
    localparam [3:0] ALU_SUB = 4'd1; 	// 0001: subtraction, retaining the original encoding.
    localparam [3:0] ALU_AND = 4'd2; 	// 0010: bitwise AND.
    localparam [3:0] ALU_OR  = 4'd3; 	// 0011: bitwise OR.
    localparam [3:0] ALU_XOR = 4'd4; 	// 0100: bitwise XOR.
    localparam [3:0] ALU_NOT = 4'd5; 	// 0101: bitwise complement of a; b is ignored.
    localparam [3:0] ALU_SLL = 4'd6; 	// 0110: logical left shift.
    localparam [3:0] ALU_SRL = 4'd7; 	// 0111: logical right shift, filling upper bits with zeros.
    localparam [3:0] ALU_SRA = 4'd8; 	// 1000: arithmetic right shift, replicating the sign bit.

    wire [3:0] shamt = b[3:0];      		// Provisional ISA: use only the low 4 bits of b, giving a shift amount of 0 to 15.

    always @(*) begin               		// Recompute when a, b or op changes; this describes combinational logic.
        case (op)                   
            ALU_ADD: y = a + b;     
            ALU_SUB: y = a - b;     
            ALU_AND: y = a & b;     		// Each result bit is 1 only if both input bits are 1; this is not logical AND (&&).
            ALU_OR:  y = a | b;     
            ALU_XOR: y = a ^ b;     
            ALU_NOT: y = ~a;        
            ALU_SLL: y = a << shamt; 		// Shift left, fill lower bits with zeros and discard bits beyond bit 15.
            ALU_SRL: y = a >> shamt; 		// Logical right shift always fills upper bits with zeros, regardless of a[15].
            ALU_SRA: y = $signed(a) >>> shamt; 	// Cast to signed before arithmetic right shift to preserve the sign.
            default: y = 16'd0;     		// Return 0 for op values 9 to 15 or containing X/Z; X/Z behavior is for simulation.
        endcase                     
    end                             
endmodule                           
