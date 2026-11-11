// =============================================================
// The CPU: wires the boxes together and runs FETCH -> EXECUTE -> COMMIT.
//
// Instruction layout (32 bits) - PLACEHOLDER until the team freezes it:
//   [31:24] opcode   (first byte, as the prof suggested)
//   [23:20] rd       destination register
//   [19:16] rs1      source register 1 (base address for LD/ST)
//   [15:12] rs2      source register 2 (the data for ST)
//   [11:0]  imm12    offset for LD/ST, ZERO-extended (prof, Oct 30:
//                    "sign extending a memory address is a bad idea")
// =============================================================
module cpu (
    input wire clk,
    input wire reset
);

    // ---------- State elements (things that REMEMBER) ----------
    reg [15:0] pc;            // program counter: which instruction is next
    reg [31:0] ir;            // instruction register: the fetched instruction
    reg [1:0]  state;         // which step we are in

    localparam FETCH = 2'd0, IR_LOAD = 2'd1, EXECUTE = 2'd2, COMMIT = 2'd3;
    // ---------- Program memory (M10K) ----------
    wire [31:0] imem_q;
    imem_m10k u_imem (.q(imem_q), .read_address(pc[5:0]), .clk(clk));
    // ---------- Decoder: just slicing bits, no logic ----------
    wire [7:0]  opcode = ir[31:24];
    wire [3:0]  rd     = ir[23:20];
    wire [3:0]  rs1    = ir[19:16];
    wire [3:0]  rs2    = ir[15:12];
    wire [15:0] imm16  = {4'd0, ir[11:0]};   // zero-extend 12 -> 16 bits

    // ---------- Control unit (the table) ----------
    wire RegWrite, WBsel, BSel, MemWrite;
    wire [3:0] ALUOp; // Part B: nine ALU operations require 4 bits, connecting control to alu.
    control ctl (.opcode(opcode), .RegWrite(RegWrite), .WBsel(WBsel),
                 .ALUOp(ALUOp), .BSel(BSel), .MemWrite(MemWrite));

    // ---------- Register file ----------
    wire [15:0] A16, B16, WB_DATA16;
    wire commit = (state == COMMIT);          // writes are only allowed here
    regfile rf (.clk(clk), .reset(reset),
                .ra(rs1), .a_data(A16),
                .rb(rs2), .b_data(B16),
                .we(RegWrite & commit), .wa(rd), .w_data(WB_DATA16));

    // ---------- BSel mux: ALU input B = register or immediate ----------
    wire [15:0] alu_b = BSel ? imm16 : B16;

    // ---------- ALU ----------
    wire [15:0] ExecResult16;
    alu u_alu (.a(A16), .b(alu_b), .op(ALUOp), .y(ExecResult16));

    // ---------- Data memory read (address comes from the ALU) ----------
    wire [15:0] addr16     = ExecResult16;
    wire [15:0] LoadData16;
    dmem_m10k u_dmem (.q(LoadData16), .d(B16),
                      .write_address(addr16[5:0]), .read_address(addr16[5:0]),
                      .we(MemWrite & commit), .clk(clk));

    // ---------- Writeback mux: what gets saved into rd ----------
    assign WB_DATA16 = WBsel ? LoadData16 : ExecResult16;

    // ---------- The state machine: the order of operations ----------
    always @(posedge clk) begin
        if (reset) begin
            pc    <= 16'd0;
            ir    <= 32'd0;
            state <= FETCH;
        end else begin
            case (state)
                FETCH: begin
                    state <= IR_LOAD;
                end
                IR_LOAD: begin
                    ir    <= imem_q;          // IRWrite: latch the instruction
                    state <= EXECUTE;
                end
                EXECUTE: begin
                    // Nothing is saved here. The muxes, ALU and memory read
                    // just settle to their answers (they are wires).
                    state <= COMMIT;
                end
                COMMIT: begin
                    // The register write happens inside regfile (we = RegWrite & commit).
                    pc    <= pc + 16'd1;                     // PCWrite, PCSel = SEQ
                    state <= FETCH;
                end
                default: state <= FETCH;
            endcase
        end
    end
endmodule
