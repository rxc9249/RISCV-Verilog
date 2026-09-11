# RISCV-Verilog
Single-cycle 32-bit RISC-V CPU written in Verilog with 18 instructions. Supports R-type, load/store, branches, immediate ALU ops, jal, lui, and auipc. Includes a testbench and waveform dump.

Datapath diagram for the single-cycle CPU. Blue lines are control signals. The basic layout follows the single-cycle design from _Computer Organization and Design_: RISC-V Edition (Patterson & Hennessy).

<img width="1680" height="1052" alt="image" src="https://github.com/user-attachments/assets/2fc5227a-9e2a-4d15-b6e0-6a6a833081a6" />

## Supported Instructions

### R-type — register and register

These take two registers, do math on them, and store the answer in a third register.

| Instruction | Meaning | What it does |
|---|---|---|
| `add rd, rs1, rs2` | Add | `rd = rs1 + rs2` |
| `sub rd, rs1, rs2` | Subtract | `rd = rs1 - rs2` |
| `and rd, rs1, rs2` | Bitwise AND | `rd = rs1 & rs2` — keeps only bits that are 1 in both |
| `or rd, rs1, rs2` | Bitwise OR | `rd = rs1 \| rs2` — keeps bits that are 1 in either |


### I-type — register and a constant

Same idea, but the second value is a number written into the instruction itself. The number is 12 bits and gets sign-extended to 32 bits, so it can be negative.

| Instruction | Meaning | What it does |
|---|---|---|
| `addi rd, rs1, imm` | Add immediate | `rd = rs1 + imm`. Use `addi rd, x0, 5` to load a small number |
| `andi rd, rs1, imm` | AND immediate | `rd = rs1 & imm` — handy for masking bits |
| `ori rd, rs1, imm` | OR immediate | `rd = rs1 \| imm` — handy for setting bits |

### Memory

The address is worked out by adding a constant to a register. This lets you index into arrays.

| Instruction | Meaning | What it does |
|---|---|---|
| `lw rd, imm(rs1)` | Load word | Reads 4 bytes from memory at `rs1 + imm` and puts them in `rd` |
| `sw rs2, imm(rs1)` | Store word | Writes the 4 bytes in `rs2` to memory at `rs1 + imm` |

### Branches — jump only if a test passes

Each one compares two registers. If the test is true, the PC jumps forward or backward by the offset. If false, the CPU just moves to the next instruction.

| Instruction | Meaning | Jumps when |
|---|---|---|
| `beq rs1, rs2, label` | Branch if equal | `rs1 == rs2` |
| `bne rs1, rs2, label` | Branch if not equal | `rs1 != rs2` |
| `blt rs1, rs2, label` | Branch if less than | `rs1 < rs2`, treating both as signed (negatives allowed) |
| `bge rs1, rs2, label` | Branch if greater or equal | `rs1 >= rs2`, signed |
| `bltu rs1, rs2, label` | Branch if less than, unsigned | `rs1 < rs2`, treating both as plain positive numbers |
| `bgeu rs1, rs2, label` | Branch if greater or equal, unsigned | `rs1 >= rs2`, unsigned |

The signed and unsigned versions matter: as signed numbers `-1 < 1`, but as unsigned bits `-1` is `0xFFFFFFFF`, which is the biggest value there is.

### Jump

| Instruction | Meaning | What it does |
|---|---|---|
| `jal rd, label` | Jump and link | Jumps to `label`, and saves the address of the *next* instruction into `rd`. That saved address is the return address, so `jal ra, func` is how you call a function |

### Upper immediate

RISC-V instructions are only 32 bits wide, so a full 32-bit constant won't fit in one. These two put a 20-bit value into the top half of a register.

| Instruction | Meaning | What it does |
|---|---|---|
| `lui rd, imm` | Load upper immediate | `rd = imm << 12`. Pair with `addi` to build any 32-bit constant |
| `auipc rd, imm` | Add upper immediate to PC | `rd = PC + (imm << 12)`. Used for position-independent addresses |


---

## Modules

| Module | Job |
|---|---|
| `Program_Counter` | Holds the address of the current instruction |
| `PCplus4` | Works out the next address in line |
| `imem` | Instruction memory — 1024 words |
| `registers` | The 32 registers. `x0` is hardwired to zero and can't be written |
| `immGen` | Pulls the constant out of the instruction and sign-extends it |
| `control_unit` | Reads the opcode and sets all the control switches |
| `ALU_control` | Turns the ALU op plus funct3/funct7 into the exact ALU operation |
| `ALU_unit` | Does the actual math — add, subtract, AND, OR |
| `branch_unit` | Runs the branch comparison and decides whether to take it |
| `data_Memory` | Data memory — 64 words |
| `muxA`, `mux1`, `mux2`, `mux3`, `muxJ` | Pick which value flows down each path |
| `top` | Wires everything together |

---

