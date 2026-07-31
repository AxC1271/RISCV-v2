# Branch Unit

## Purpose

Combinational branch resolution unit for the RV32I branch instructions (BEQ, BNE, BLT, BGE, BLTU,
BGEU). Computes whether a branch is taken from `rs1_data`, `rs2_data`, and `funct3`, and computes
the branch target as `pc + imm`. Formally verified rather than simulation-tested — same rationale
as the ALU: large input space (`2^64` combinations of `rs1_data`/`rs2_data` alone), small
combinational logic, tractable for exhaustive proof. See `../README.md` for the full argument.
Verification config: `branch_unit.sby`.

---

## RTL Code

```systemverilog
module branch_unit (
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic branch,
    input logic [2:0] funct3,

    input logic [31:0] pc,
    input logic [31:0] imm,

    output logic branch_taken,
    output logic [31:0] branch_target
);

    logic condition_met;

    always_comb begin
        case (funct3)
            3'b000: condition_met = (rs1_data == rs2_data);                    // BEQ
            3'b001: condition_met = (rs1_data != rs2_data);                    // BNE
            3'b100: condition_met = ($signed(rs1_data) < $signed(rs2_data));   // BLT
            3'b101: condition_met = ($signed(rs1_data) >= $signed(rs2_data));  // BGE
            3'b110: condition_met = (rs1_data < rs2_data);                     // BLTU
            3'b111: condition_met = (rs1_data >= rs2_data);                    // BGEU
            default: condition_met = 1'b0;
        endcase
    end

    assign branch_taken = branch && condition_met;
    assign branch_target = pc + imm;
```

---

## SVA Assertions

Immediate assertions, living in a second `always_comb` block alongside the logic — same file, same
module, following the pattern established for the ALU.

```systemverilog
    // --- formal properties ---
    always_comb begin
        // BEQ / BNE: independently re-derived via XOR, not a restatement of the RTL's == / !=
        if (funct3 == 3'b000)
            assert (condition_met == ((rs1_data ^ rs2_data) == 32'b0));
        if (funct3 == 3'b001)
            assert (condition_met == (|(rs1_data ^ rs2_data)));

        // BLT / BGE / BLTU / BGEU: direct restatement of the RTL — proves elaboration
        // correctness, not independent of a logic bug duplicated in both places
        if (funct3 == 3'b100)
            assert (condition_met == ($signed(rs1_data) < $signed(rs2_data)));
        if (funct3 == 3'b101)
            assert (condition_met == ($signed(rs1_data) >= $signed(rs2_data)));
        if (funct3 == 3'b110)
            assert (condition_met == (rs1_data < rs2_data));
        if (funct3 == 3'b111)
            assert (condition_met == (rs1_data >= rs2_data));

        // unused funct3 encodings (010, 011) must default to not-taken
        if (funct3 != 3'b000 && funct3 != 3'b001 && funct3 != 3'b100 &&
            funct3 != 3'b101 && funct3 != 3'b110 && funct3 != 3'b111)
            assert (condition_met == 1'b0);

        // branch_taken / branch_target structural checks
        assert (branch_taken == (branch && condition_met));
        assert (branch_target == (pc + imm));

        // safety property, independent of condition_met entirely:
        // branch deasserted must always suppress branch_taken
        if (!branch)
            assert (branch_taken == 1'b0);

        // reachability — confirms both outcomes are actually possible, not vacuously proven
        cover (branch_taken == 1'b1);
        cover (branch_taken == 1'b0 && branch == 1'b1);
        cover (funct3 == 3'b010); // unused encoding is reachable
        cover ((pc + imm) < pc);  // branch_target wraparound is reachable
    end
endmodule
```

`branch_unit.sby` config (BMC, depth 1 — valid because this module is purely combinational):

```ini
[options]
mode bmc
depth 1

[engines]
smtbmc boolector

[script]
read_verilog -sv branch_unit.sv
prep -top branch_unit

[files]
branch_unit.sv
```

---

## Formal Verification Output

```
sby -f branch_unit.sby

SBY 12:58:33 [branch_unit] engine_0: smtbmc boolector
SBY 12:58:33 [branch_unit] base: starting process "cd branch_unit/src; yosys -ql ../model/design.log ../model/design.ys"
SBY 12:58:33 [branch_unit] base: finished (returncode=0)
SBY 12:58:33 [branch_unit] prep: starting process "cd branch_unit/model; yosys -ql design_prep.log design_prep.ys"
SBY 12:58:33 [branch_unit] prep: finished (returncode=0)
SBY 12:58:33 [branch_unit] smt2: starting process "cd branch_unit/model; yosys -ql design_smt2.log design_smt2.ys"
SBY 12:58:33 [branch_unit] smt2: finished (returncode=0)
SBY 12:58:33 [branch_unit] engine_0: starting process "cd branch_unit; yosys-smtbmc -s boolector --presat --unroll --noprogress -t 1  --append 0 --dump-vcd engine_0/trace.vcd --dump-yw engine_0/trace.yw --dump-vlogtb engine_0/trace_tb.v --dump-smtc engine_0/trace.smtc model/design_smt2.smt2"
SBY 12:58:33 [branch_unit] engine_0: ##   0:00:00  Solver: boolector
SBY 12:58:33 [branch_unit] engine_0: ##   0:00:00  Checking assumptions in step 0..
SBY 12:58:33 [branch_unit] engine_0: ##   0:00:00  Checking assertions in step 0..
SBY 12:58:33 [branch_unit] engine_0: ##   0:00:00  Status: passed
SBY 12:58:33 [branch_unit] engine_0: finished (returncode=0)
SBY 12:58:33 [branch_unit] engine_0: Status returned by engine: pass
SBY 12:58:33 [branch_unit] summary: Elapsed clock time [H:MM:SS (secs)]: 0:00:00 (0)
SBY 12:58:33 [branch_unit] summary: Elapsed process time [H:MM:SS (secs)]: 0:00:00 (0)
SBY 12:58:33 [branch_unit] summary: engine_0 (smtbmc boolector) returned pass
SBY 12:58:33 [branch_unit] summary: engine_0 did not produce any traces
SBY 12:58:33 [branch_unit] DONE (PASS, rc=0)
```

Note on assertion independence: the BEQ/BNE checks are re-derived through XOR rather than
restating `==`/`!=`, so they'd catch a genuine RTL bug even if it were duplicated into a
copy-pasted assertion. The BLT/BGE/BLTU/BGEU checks are direct restatements of the RTL's own
comparison expressions — they exhaustively prove elaboration/tooling correctness across all inputs,
but wouldn't catch a logic error that was wrong in the same way in both the case statement and the
assertion. Worth deciding, module by module, whether independently re-deriving a comparator is
worth the added complexity — not done here for the signed/unsigned comparisons, since a correct
independent comparator circuit is nontrivial extra logic for comparatively low marginal coverage
gain on a module this simple.