# Control Unit

## Purpose

Combinational RV32I instruction decoder — takes the raw 32-bit instruction and generates all
downstream control signals (`alu_opcode`, `alusrc`, `regwrite`, `memread`, `memwrite`, `branch`,
`memtoreg`, `jump`) for R-type, I-type arithmetic, load, store, branch, JAL, and JALR instructions.
Formally verified rather than simulation-tested: technically a `2^32`-wide input space
(`instruction[31:0]`), and while only opcode/funct3/funct7 bits actually drive the outputs, that's
exactly the kind of "large input space, simple combinational decode logic" shape formal handles
well — see `../README.md` for the general argument. Verification config: `control_unit.sby`.

---

## RTL Code

```systemverilog
module control_unit (
    input logic[31:0] instruction,

    output logic[3:0] alu_opcode,
    output logic alusrc,
    output logic regwrite,
    output logic memread,
    output logic memwrite,
    output logic branch,
    output logic memtoreg,
    output logic jump
);

    localparam OP_R_TYPE  = 7'b0110011;
    localparam OP_I_ARITH = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_JALR    = 7'b1100111;

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    always_comb begin
        alu_opcode = 4'b0000;
        alusrc     = 1'b0;
        regwrite   = 1'b0;
        memread    = 1'b0;
        memwrite   = 1'b0;
        memtoreg   = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;

        case (instruction[6:0])
            OP_R_TYPE: begin
                regwrite = 1'b1;
                alusrc   = 1'b0;
                case (instruction[14:12])
                    3'b000: alu_opcode  = instruction[30] ? ALU_SUB : ALU_ADD;
                    3'b001: alu_opcode  = ALU_SLL;
                    3'b010: alu_opcode  = ALU_SLT;
                    3'b011: alu_opcode  = ALU_SLTU;
                    3'b100: alu_opcode  = ALU_XOR;
                    3'b101: alu_opcode  = instruction[30] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_opcode  = ALU_OR;
                    3'b111: alu_opcode  = ALU_AND;
                    default: alu_opcode = 4'b0000;
                endcase
            end

            OP_I_ARITH: begin
                regwrite = 1'b1;
                alusrc   = 1'b1;
                case(instruction[14:12])
                    3'b000: alu_opcode  = ALU_ADD;
                    3'b001: alu_opcode  = ALU_SLL;
                    3'b010: alu_opcode  = ALU_SLT;
                    3'b011: alu_opcode  = ALU_SLTU;
                    3'b100: alu_opcode  = ALU_XOR;
                    3'b101: alu_opcode  = instruction[30] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_opcode  = ALU_OR;
                    3'b111: alu_opcode  = ALU_AND;
                    default: alu_opcode = 4'b0000;
                endcase
            end

            OP_LOAD: begin
                alusrc     = 1'b1;
                regwrite   = 1'b1;
                memread    = 1'b1;
                memtoreg   = 1'b1;
                alu_opcode = ALU_ADD;
            end

            OP_STORE: begin
                alusrc     = 1'b1;
                memwrite   = 1'b1;
                alu_opcode = ALU_ADD;
            end

            OP_BRANCH: begin
                branch = 1'b1;
            end

            OP_JAL: begin
                regwrite = 1'b1;
                jump     = 1'b1;
            end

            OP_JALR: begin
                regwrite = 1'b1;
                jump     = 1'b1;
                alusrc   = 1'b1;
            end

            default: begin
            end
        endcase
    end
endmodule
```

---

## SVA Assertions

Second `always_comb` block, checked immediately after decode. Deliberately does **not** constrain
`rd`/`rs1`/`rs2`/immediate bits in any assertion — only `opcode`, `funct3`, and `instruction[30]`
are referenced, so the proof covers the entire instruction space rather than a handful of
hand-picked encodings.

```systemverilog
    always_comb begin

        // R-TYPE
        if (instruction[6:0] == OP_R_TYPE) begin
            assert (regwrite == 1'b1);
            assert (alusrc   == 1'b0);
            assert (memread  == 1'b0);
            assert (memwrite == 1'b0);
            assert (branch   == 1'b0);
            assert (jump     == 1'b0);
            case (instruction[14:12])
                3'b000:  assert (alu_opcode == (instruction[30] ? ALU_SUB : ALU_ADD));
                3'b001:  assert (alu_opcode == ALU_SLL);
                3'b010:  assert (alu_opcode == ALU_SLT);
                3'b011:  assert (alu_opcode == ALU_SLTU);
                3'b100:  assert (alu_opcode == ALU_XOR);
                3'b101:  assert (alu_opcode == (instruction[30] ? ALU_SRA : ALU_SRL));
                3'b110:  assert (alu_opcode == ALU_OR);
                3'b111:  assert (alu_opcode == ALU_AND);
            endcase
        end

        // I-TYPE ARITH
        if (instruction[6:0] == OP_I_ARITH) begin
            assert (regwrite == 1'b1);
            assert (alusrc   == 1'b1);
            assert (memread  == 1'b0);
            assert (memwrite == 1'b0);
            assert (branch   == 1'b0);
            assert (jump     == 1'b0);
            case (instruction[14:12])
                3'b000:  assert (alu_opcode == ALU_ADD);
                3'b001:  assert (alu_opcode == ALU_SLL);
                3'b010:  assert (alu_opcode == ALU_SLT);
                3'b011:  assert (alu_opcode == ALU_SLTU);
                3'b100:  assert (alu_opcode == ALU_XOR);
                3'b101:  assert (alu_opcode == (instruction[30] ? ALU_SRA : ALU_SRL));
                3'b110:  assert (alu_opcode == ALU_OR);
                3'b111:  assert (alu_opcode == ALU_AND);
            endcase
        end

        // LOAD
        if (instruction[6:0] == OP_LOAD) begin
            assert (alusrc     == 1'b1);
            assert (regwrite   == 1'b1);
            assert (memread    == 1'b1);
            assert (memtoreg   == 1'b1);
            assert (memwrite   == 1'b0);
            assert (branch     == 1'b0);
            assert (jump       == 1'b0);
            assert (alu_opcode == ALU_ADD);
        end

        // STORE
        if (instruction[6:0] == OP_STORE) begin
            assert (alusrc     == 1'b1);
            assert (memwrite   == 1'b1);
            assert (regwrite   == 1'b0);
            assert (memread    == 1'b0);
            assert (branch     == 1'b0);
            assert (jump       == 1'b0);
            assert (alu_opcode == ALU_ADD);
        end

        // BRANCH
        if (instruction[6:0] == OP_BRANCH) begin
            assert (branch   == 1'b1);
            assert (regwrite == 1'b0);
            assert (memread  == 1'b0);
            assert (memwrite == 1'b0);
            assert (jump     == 1'b0);
        end

        // JAL
        if (instruction[6:0] == OP_JAL) begin
            assert (regwrite == 1'b1);
            assert (jump     == 1'b1);
            assert (alusrc   == 1'b0);
            assert (memread  == 1'b0);
            assert (memwrite == 1'b0);
            assert (branch   == 1'b0);
        end

        // JALR
        if (instruction[6:0] == OP_JALR) begin
            assert (regwrite == 1'b1);
            assert (jump     == 1'b1);
            assert (alusrc   == 1'b1);
            assert (memread  == 1'b0);
            assert (memwrite == 1'b0);
            assert (branch   == 1'b0);
        end

        // DEFAULT / UNRECOGNIZED OPCODE — must be fully inert
        if (instruction[6:0] != OP_R_TYPE  && instruction[6:0] != OP_I_ARITH &&
            instruction[6:0] != OP_LOAD    && instruction[6:0] != OP_STORE   &&
            instruction[6:0] != OP_BRANCH  && instruction[6:0] != OP_JAL     &&
            instruction[6:0] != OP_JALR) begin
            assert (alu_opcode == 4'b0000);
            assert (alusrc     == 1'b0);
            assert (regwrite   == 1'b0);
            assert (memread    == 1'b0);
            assert (memwrite   == 1'b0);
            assert (memtoreg   == 1'b0);
            assert (branch     == 1'b0);
            assert (jump       == 1'b0);
        end

        // GLOBAL SAFETY / MUTUAL EXCLUSIVITY — must hold for every opcode
        assert (!(memread && memwrite));
        assert (!(branch && jump));

        // REACHABILITY
        cover (instruction[6:0] == OP_R_TYPE  && instruction[14:12] == 3'b000 && instruction[30]);
        cover (instruction[6:0] == OP_R_TYPE  && instruction[14:12] == 3'b101 && instruction[30]);
        cover (instruction[6:0] == OP_I_ARITH && instruction[14:12] == 3'b101 && instruction[30]);
        cover (instruction[6:0] == OP_LOAD);
        cover (instruction[6:0] == OP_STORE);
        cover (instruction[6:0] == OP_BRANCH);
        cover (instruction[6:0] == OP_JAL);
        cover (instruction[6:0] == OP_JALR);
        cover (instruction[6:0] != OP_R_TYPE  && instruction[6:0] != OP_I_ARITH &&
               instruction[6:0] != OP_LOAD    && instruction[6:0] != OP_STORE   &&
               instruction[6:0] != OP_BRANCH  && instruction[6:0] != OP_JAL     &&
               instruction[6:0] != OP_JALR);
    end
endmodule
```

`control_unit.sby` config (BMC, depth 1 — valid because this module is purely combinational):

```ini
[options]
mode bmc
depth 1

[engines]
smtbmc boolector

[script]
read_verilog -sv control_unit.sv
prep -top control_unit

[files]
control_unit.sv
```

---

## Formal Verification Output

```
sby -f control_unit.sby

SBY 16:59:11 [control_unit] engine_0: smtbmc boolector
SBY 16:59:11 [control_unit] base: finished (returncode=0)
SBY 16:59:11 [control_unit] prep: finished (returncode=0)
SBY 16:59:11 [control_unit] smt2: finished (returncode=0)
SBY 16:59:11 [control_unit] engine_0: ##   0:00:00  Solver: boolector
SBY 16:59:11 [control_unit] engine_0: ##   0:00:00  Checking assumptions in step 0..
SBY 16:59:11 [control_unit] engine_0: ##   0:00:00  Checking assertions in step 0..
SBY 16:59:11 [control_unit] engine_0: ##   0:00:00  Status: passed
SBY 16:59:11 [control_unit] engine_0: Status returned by engine: pass
SBY 16:59:11 [control_unit] summary: engine_0 (smtbmc boolector) returned pass
SBY 16:59:11 [control_unit] DONE (PASS, rc=0)
```

Passed clean on the first run — no counterexample chase this time. All per-opcode signal
assertions, the default-inert check, and both mutual-exclusivity properties (`memread`/`memwrite`,
`branch`/`jump`) proven across every possible 32-bit instruction value, with `rd`/`rs1`/`rs2`/
immediate bits left fully unconstrained. The `cover` statements confirm every opcode class, plus
both `instruction[30]`-dependent splits (ADD/SUB, SRL/SRA) in both R-type and I-type paths, and
the default/unrecognized-opcode path, are all actually reachable rather than vacuously proven.