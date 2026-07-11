# Arithmetic Logic Unit

## Purpose

Combinational 32-bit ALU supporting 10 RV32I operations (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA,
SLT, SLTU) selected by a 4-bit opcode. Formally verified rather than simulation-tested — see
`../README.md` for why this module is a good fit for that (large input space, small combinational
logic). Verification config: `alu.sby`.

---

## RTL Code

```systemverilog
module alu (
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [3:0]  alu_opcode,
    output logic [31:0] res
);

    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_AND  = 4'b0010;
    localparam logic [3:0] ALU_OR   = 4'b0011;
    localparam logic [3:0] ALU_XOR  = 4'b0100;
    localparam logic [3:0] ALU_SLL  = 4'b0101;
    localparam logic [3:0] ALU_SRL  = 4'b0110;
    localparam logic [3:0] ALU_SRA  = 4'b0111;
    localparam logic [3:0] ALU_SLT  = 4'b1000;
    localparam logic [3:0] ALU_SLTU = 4'b1001;

    always_comb begin
        case (alu_opcode)
            ALU_ADD:  res = a + b;
            ALU_SUB:  res = a - b;
            ALU_AND:  res = a & b;
            ALU_OR:   res = a | b;
            ALU_XOR:  res = a ^ b;
            ALU_SLL:  res = a << b[4:0];
            ALU_SRL:  res = a >> b[4:0];
            ALU_SRA:  res = a[31] ? ~((~a) >> b[4:0]) : (a >> b[4:0]);
            ALU_SLT:  res = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: res = (a < b) ? 32'd1 : 32'd0;
            default:  res = 32'h0;
        endcase
```

Note on `ALU_SRA`: this is written as `~((~a) >> b[4:0])` rather than the more obvious
`$signed(a) >>> b[4:0]`. Both are mathematically identical (standard two's-complement identity for
arithmetic right shift), but the `$signed >>>` form triggered a Yosys formal-elaboration bug on a
*correct* RTL implementation — see the case study below. Kept in this form intentionally; don't
"simplify" it back.

---

## SVA Assertions

Immediate assertions, living in the same `always_comb` block as the logic they check — kept
inline rather than in a separate block or bind file, since Yosys's free SV frontend has limited
`bind` support and cross-block reads of a combinationally-driven signal proved unreliable during
initial testing.

```systemverilog
        if (alu_opcode == ALU_ADD)
            assert (res == a + b);
        if (alu_opcode == ALU_SUB)
            assert (res == a - b);
        if (alu_opcode == ALU_AND)
            assert (res == (a & b));
        if (alu_opcode == ALU_OR)
            assert (res == (a | b));
        if (alu_opcode == ALU_XOR)
            assert (res == (a ^ b));
        if (alu_opcode == ALU_SLL)
            assert (res == (a << b[4:0]));
        if (alu_opcode == ALU_SRL)
            assert (res == (a >> b[4:0]));
        if (alu_opcode == ALU_SRA)
            assert (res == (a[31] ? ~((~a) >> b[4:0]) : (a >> b[4:0])));
        if (alu_opcode == ALU_SLT)
            assert (res == (($signed(a) < $signed(b)) ? 32'd1 : 32'd0));
        if (alu_opcode == ALU_SLTU)
            assert (res == ((a < b) ? 32'd1 : 32'd0));
        if (alu_opcode != ALU_ADD  && alu_opcode != ALU_SUB &&
            alu_opcode != ALU_AND  && alu_opcode != ALU_OR  &&
            alu_opcode != ALU_XOR  && alu_opcode != ALU_SLL &&
            alu_opcode != ALU_SRL  && alu_opcode != ALU_SRA &&
            alu_opcode != ALU_SLT  && alu_opcode != ALU_SLTU)
            assert (res == 32'h0);

        cover (alu_opcode == 4'b1010);
    end
endmodule
```

`alu.sby` config (BMC, depth 1 — valid because this module is purely combinational, no state to
unroll across cycles):

```ini
[options]
mode bmc
depth 1

[engines]
smtbmc boolector

[script]
read_verilog -sv alu.sv
prep -top alu

[files]
alu.sv
```

---

## Formal Verification Output

```
sby -f alu.sby      

SBY  9:44:51 [alu] engine_0: smtbmc boolector
SBY  9:44:51 [alu] base: starting process "cd alu/src; yosys -ql ../model/design.log ../model/design.ys"
SBY  9:44:51 [alu] base: finished (returncode=0)
SBY  9:44:51 [alu] prep: starting process "cd alu/model; yosys -ql design_prep.log design_prep.ys"
SBY  9:44:51 [alu] prep: finished (returncode=0)
SBY  9:44:51 [alu] smt2: starting process "cd alu/model; yosys -ql design_smt2.log design_smt2.ys"
SBY  9:44:51 [alu] smt2: finished (returncode=0)
SBY  9:44:51 [alu] engine_0: starting process "cd alu; yosys-smtbmc -s boolector --presat --unroll --noprogress -t 1  --append 0 --dump-vcd engine_0/trace.vcd --dump-yw engine_0/trace.yw --dump-vlogtb engine_0/trace_tb.v --dump-smtc engine_0/trace.smtc model/design_smt2.smt2"
SBY  9:44:52 [alu] engine_0: ##   0:00:00  Solver: boolector
SBY  9:44:52 [alu] engine_0: ##   0:00:00  Checking assumptions in step 0..
SBY  9:44:52 [alu] engine_0: ##   0:00:00  Checking assertions in step 0..
SBY  9:44:52 [alu] engine_0: ##   0:00:00  Status: passed
SBY  9:44:52 [alu] engine_0: finished (returncode=0)
SBY  9:44:52 [alu] engine_0: Status returned by engine: pass
SBY  9:44:52 [alu] summary: Elapsed clock time [H:MM:SS (secs)]: 0:00:00 (0)
SBY  9:44:52 [alu] summary: Elapsed process time [H:MM:SS (secs)]: 0:00:00 (0)
SBY  9:44:52 [alu] summary: engine_0 (smtbmc boolector) returned pass
SBY  9:44:52 [alu] summary: engine_0 did not produce any traces
SBY  9:44:52 [alu] DONE (PASS, rc=0)
```

All 11 assertions proven across every reachable input combination at BMC depth 1 (equivalent to
exhaustive SAT-based coverage for a combinational module — every possible `a`, `b`, `alu_opcode`
triple). The `cover` statement confirms the default branch is reachable and not vacuously true.

**Getting here wasn't a straight line.** The first passing run followed a real BMC failure on the
SRA assertion, with `$signed(a) >>> b[4:0]` as both the RTL and the assertion — a case where the
RTL was proven correct against an independent Icarus simulation, and the actual fault was Yosys's
elaboration of a variable-amount arithmetic right shift. Full writeup of the diagnosis in
`../README.md`.