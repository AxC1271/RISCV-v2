# Pipelining Registers

## Purpose

These pipeline registers elevate the design from a single-core processor to a multi-stage pipeline. Why is this so significant? We need to discuss critical paths to see why this matters:

Remember the setup time equation, as this governs the fastest your design can go at before failing timing:

$$
t_{clk} + t_{skew} \geq t_{cq} + t_{comb} + t_{setup}
$$

The issue we are most concerned with is the parameter $ t_{comb} $. In a single processor design, the only "registers" in your design are at the beginning and at the end of the pipeline, meaning that your design's critical path is the entire length of the pipeline. Take a load instruction for example: the load instruction goes from your program counter to instruction memory, to your register file and control unit, then to your ALU to calculate the address in memory, reads the data from that address in memory, before being muxed and finally written back to the register file. You need to allow enough time between clock cycles for that entire combinational path to finish (if your clock flips before the load instruction is finished, you'll have data corruption or in other words, a setup time violation). 

For setup time violations, pipelining is a common approach as you're breaking up your critical path into smaller sections. In CPU design, this logic also applies: you're now splitting your critical path into 5 different stages, and you're only bottlenecked by the slowest stage as opposed to the entire stage. Imagine if your critical path was 10ns in the single-cycle processor (hence your max frequency is 100MHz); splitting it into 5 different stages (in real life this is never perfectly symmetrical and $ t_{cq} $ / $ t_{setup} $ do provide nonnegligible delay) means your critical path is 2ns, effectively boosting your max frequency to 500MHz. 

---

## RTL Code

Check the directory for a detailed implementation of each pipeline register. Under normal operations, the pipeline registers forward data to the next stage but you'll have to be wary of data hazards that can happen (that couldn't happen in a single-cycle design):

- RAW hazards 
- Load-use hazards
- Branch mispredictions

---

## Simulation + Waveform

---