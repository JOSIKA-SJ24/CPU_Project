# CPU project: Verilog simulation

A 16-bit CPU with 32-bit instructions, 16 registers (R0 = 0), separate program and data memory, and a FETCH → EXECUTE → COMMIT state machine.

## Status

| Instruction | Owner | Status |
|---|---|---|
| LD  | Josika | Done, passes test |
| ADD | Josika | Done, passes test |
| SUB | | To do: one ALU case in `rtl/alu.v`, one row in `rtl/control.v` (marked TODO) |
| SW  | | To do: one row in `rtl/control.v` (marked TODO). The store data path is already wired in `rtl/cpu.v` |

## Files

```
rtl/        synthesizable design (goes on the FPGA)
  regfile.v   16 x 16-bit registers, 2 read ports, 1 write port, R0 = 0
  alu.v       execution unit
  control.v   opcode -> control signals (one row per instruction)
  cpu.v       datapath wiring + FETCH/EXECUTE/COMMIT state machine
tb/         testbench (simulation only, not synthesizable)
  tb_cpu.v    clock, reset, loads memories, prints a trace, checks results
programs/
  program.hex test program
  data.hex    starting data memory
```

## Instruction format (placeholder until the team freezes it)

| Bits | 31:24 | 23:20 | 19:16 | 15:12 | 11:0 |
|---|---|---|---|---|---|
| Field | opcode | rd | rs1 | rs2 | imm12 (zero-extended, per prof Oct 30) |

Opcodes: NOP 00, ADD 01, SUB 02, LD 10, ST 11.

## Run in ModelSim

1. Make a folder and copy **all** the files into it, including both `.hex` files (`$readmemh` looks for them in the ModelSim project folder).
2. ModelSim: **File → New → Project**, and set the project location to that folder.
3. **Add Existing File**: `tb_cpu.v`, `cpu.v`, `control.v`, `alu.v`, `regfile.v`.
4. **Compile → Compile All**. All five should show a green check.
5. **Simulate → Start Simulation**, then pick **work → tb_cpu**.
6. In the Transcript window, type `run -all`. The trace and the PASS line are printed there.
7. Optional: to see the waveforms, add signals with **Add → To Wave → Selected Signals** before running.

Reference: Prof. Land's ModelSim guide, https://people.ece.cornell.edu/land/courses/ece5760/ModelSim/index.html

## Expected output

```
PC=0  LD  R1, 0(R0)   -> R1 = 5 (read from DMEM[0])
PC=1  LD  R2, 1(R0)   -> R2 = 7 (read from DMEM[1])
PC=2  ADD R3, R1, R2  -> 5 + 7 = 12
PASS: LD and ADD work.
```
