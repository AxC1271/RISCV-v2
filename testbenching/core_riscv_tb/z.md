# Debugging Report

## RISC-V Assembly Payload

```
32'h06400093; // addi x1, x0, 100    # base = 100
32'h02A00113; // addi x2, x0, 42     # val = 42
32'h0020A023; // sw   x2, 0(x1)      # mem[100] = 42
32'h06300193; // addi x3, x0, 99     # val = 99
32'h0030A223; // sw   x3, 4(x1)      # mem[104] = 99
32'h0000A203; // lw   x4, 0(x1)      # x4 = 42
32'h000202B3; // add  x5, x4, x0     # x5 = x4  (load-use stall)
32'h0040A303; // lw   x6, 4(x1)      # x6 = 99
32'h404303B3; // sub  x7, x6, x4     # x7 = 57
```

Based on looking at this code, we can derive by hand the following outputs:

```
x1 = 100
x2 = 42
x3 = 99
x4 = 42
x5 = 42
x6 = 99
x7 = 57

mem[100] = 42
mem[104] = 99
```

---

## Simulation Results

```
[T=55000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0

[TB] CPU running...
[T=65000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=75000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=85000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=95000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=105000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=115000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=125000] | IF: PC=00000000 | ID: 00000000 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=135000] | IF: PC=00000004 | ID: 06400093 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=145000] | IF: PC=00000008 | ID: 06400093 | EX: rd=x1 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=155000] | IF: PC=0000000c | ID: 02a00113 | EX: rd=x1 mrd=0 mwr=0 | MEM: rd=x1 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=165000] | IF: PC=00000010 | ID: 0020a023 | EX: rd=x2 mrd=0 mwr=0 | MEM: rd=x1 mrd=0 mwr=0 mw=1 | WB: rd=x1 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=175000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=1 | MEM: rd=x2 mrd=0 mwr=0 mw=1 | WB: rd=x1 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=185000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x3 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x2 rw=1 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=195000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=205000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=215000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=225000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=0 dcache_rdy=0
[T=235000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=245000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=1
[T=255000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x3 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=265000] | IF: PC=00000018 | ID: 0000a203 | EX: rd=x3 mrd=0 mwr=0 | MEM: rd=x3 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=275000] | IF: PC=0000001c | ID: 0000a203 | EX: rd=x4 mrd=1 mwr=0 | MEM: rd=x3 mrd=0 mwr=0 mw=1 | WB: rd=x3 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=285000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x4 mrd=1 mwr=0 | MEM: rd=x4 mrd=1 mwr=0 mw=1 | WB: rd=x3 rw=1 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=0 dcache_rdy=0
[T=295000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x4 mrd=1 mwr=0 mw=1 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=1
[T=305000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x5 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x4 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=1
[T=315000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x5 mrd=0 mwr=0 | MEM: rd=x5 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=325000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x5 mrd=0 mwr=0 | MEM: rd=x5 mrd=0 mwr=0 mw=1 | WB: rd=x5 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=335000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x5 mrd=0 mwr=0 | MEM: rd=x5 mrd=0 mwr=0 mw=1 | WB: rd=x5 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=345000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x5 mrd=0 mwr=0 | MEM: rd=x5 mrd=0 mwr=0 mw=1 | WB: rd=x5 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=355000] | IF: PC=00000020 | ID: 000202b3 | EX: rd=x5 mrd=0 mwr=0 | MEM: rd=x5 mrd=0 mwr=0 mw=1 | WB: rd=x5 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=365000] | IF: PC=00000024 | ID: 404303b3 | EX: rd=x5 mrd=0 mwr=0 | MEM: rd=x5 mrd=0 mwr=0 mw=1 | WB: rd=x5 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=375000] | IF: PC=00000028 | ID: 404303b3 | EX: rd=x7 mrd=0 mwr=0 | MEM: rd=x5 mrd=0 mwr=0 mw=1 | WB: rd=x5 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=385000] | IF: PC=0000002c | ID: 00000013 | EX: rd=x7 mrd=0 mwr=0 | MEM: rd=x7 mrd=0 mwr=0 mw=1 | WB: rd=x5 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=395000] | IF: PC=00000030 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x7 mrd=0 mwr=0 mw=1 | WB: rd=x7 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=405000] | IF: PC=00000034 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x7 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=415000] | IF: PC=00000034 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=425000] | IF: PC=00000034 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=435000] | IF: PC=00000034 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=445000] | IF: PC=00000034 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=455000] | IF: PC=00000034 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=465000] | IF: PC=00000038 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=475000] | IF: PC=0000003c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=485000] | IF: PC=00000040 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=495000] | IF: PC=00000044 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=505000] | IF: PC=00000044 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=515000] | IF: PC=00000044 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=525000] | IF: PC=00000044 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=535000] | IF: PC=00000044 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=545000] | IF: PC=00000044 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=555000] | IF: PC=00000048 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=565000] | IF: PC=0000004c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=575000] | IF: PC=00000050 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=585000] | IF: PC=00000054 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=595000] | IF: PC=00000054 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=605000] | IF: PC=00000054 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=615000] | IF: PC=00000054 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=625000] | IF: PC=00000054 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=635000] | IF: PC=00000054 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=645000] | IF: PC=00000058 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=655000] | IF: PC=0000005c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=665000] | IF: PC=00000060 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=675000] | IF: PC=00000064 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=685000] | IF: PC=00000064 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=695000] | IF: PC=00000064 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=705000] | IF: PC=00000064 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=715000] | IF: PC=00000064 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=725000] | IF: PC=00000064 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=735000] | IF: PC=00000068 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=745000] | IF: PC=0000006c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=755000] | IF: PC=00000070 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=765000] | IF: PC=00000074 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=775000] | IF: PC=00000074 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=785000] | IF: PC=00000074 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=795000] | IF: PC=00000074 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=805000] | IF: PC=00000074 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=815000] | IF: PC=00000074 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=825000] | IF: PC=00000078 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=835000] | IF: PC=0000007c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=845000] | IF: PC=00000080 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=855000] | IF: PC=00000084 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=865000] | IF: PC=00000084 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=875000] | IF: PC=00000084 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=885000] | IF: PC=00000084 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=895000] | IF: PC=00000084 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=905000] | IF: PC=00000084 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=915000] | IF: PC=00000088 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=925000] | IF: PC=0000008c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=935000] | IF: PC=00000090 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=945000] | IF: PC=00000094 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=955000] | IF: PC=00000094 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=965000] | IF: PC=00000094 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=975000] | IF: PC=00000094 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=985000] | IF: PC=00000094 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=995000] | IF: PC=00000094 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1005000] | IF: PC=00000098 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1015000] | IF: PC=0000009c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1025000] | IF: PC=000000a0 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1035000] | IF: PC=000000a4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1045000] | IF: PC=000000a4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1055000] | IF: PC=000000a4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1065000] | IF: PC=000000a4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1075000] | IF: PC=000000a4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1085000] | IF: PC=000000a4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1095000] | IF: PC=000000a8 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1105000] | IF: PC=000000ac | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1115000] | IF: PC=000000b0 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1125000] | IF: PC=000000b4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1135000] | IF: PC=000000b4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1145000] | IF: PC=000000b4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1155000] | IF: PC=000000b4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1165000] | IF: PC=000000b4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1175000] | IF: PC=000000b4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1185000] | IF: PC=000000b8 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1195000] | IF: PC=000000bc | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1205000] | IF: PC=000000c0 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1215000] | IF: PC=000000c4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1225000] | IF: PC=000000c4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1235000] | IF: PC=000000c4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1245000] | IF: PC=000000c4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1255000] | IF: PC=000000c4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1265000] | IF: PC=000000c4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1275000] | IF: PC=000000c8 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1285000] | IF: PC=000000cc | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1295000] | IF: PC=000000d0 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1305000] | IF: PC=000000d4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1315000] | IF: PC=000000d4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1325000] | IF: PC=000000d4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1335000] | IF: PC=000000d4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1345000] | IF: PC=000000d4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1355000] | IF: PC=000000d4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1365000] | IF: PC=000000d8 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1375000] | IF: PC=000000dc | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1385000] | IF: PC=000000e0 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1395000] | IF: PC=000000e4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1405000] | IF: PC=000000e4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1415000] | IF: PC=000000e4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1425000] | IF: PC=000000e4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1435000] | IF: PC=000000e4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1445000] | IF: PC=000000e4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1455000] | IF: PC=000000e8 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1465000] | IF: PC=000000ec | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1475000] | IF: PC=000000f0 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1485000] | IF: PC=000000f4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1495000] | IF: PC=000000f4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1505000] | IF: PC=000000f4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1515000] | IF: PC=000000f4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1525000] | IF: PC=000000f4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1535000] | IF: PC=000000f4 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1545000] | IF: PC=000000f8 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1555000] | IF: PC=000000fc | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1565000] | IF: PC=00000100 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1575000] | IF: PC=00000104 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1585000] | IF: PC=00000104 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1595000] | IF: PC=00000104 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1605000] | IF: PC=00000104 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1615000] | IF: PC=00000104 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1625000] | IF: PC=00000104 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1635000] | IF: PC=00000108 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1645000] | IF: PC=0000010c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1655000] | IF: PC=00000110 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1665000] | IF: PC=00000114 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1675000] | IF: PC=00000114 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1685000] | IF: PC=00000114 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1695000] | IF: PC=00000114 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1705000] | IF: PC=00000114 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1715000] | IF: PC=00000114 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1725000] | IF: PC=00000118 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1735000] | IF: PC=0000011c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1745000] | IF: PC=00000120 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1755000] | IF: PC=00000124 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1765000] | IF: PC=00000124 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1775000] | IF: PC=00000124 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1785000] | IF: PC=00000124 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1795000] | IF: PC=00000124 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1805000] | IF: PC=00000124 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1815000] | IF: PC=00000128 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1825000] | IF: PC=0000012c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1835000] | IF: PC=00000130 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1845000] | IF: PC=00000134 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1855000] | IF: PC=00000134 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1865000] | IF: PC=00000134 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1875000] | IF: PC=00000134 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1885000] | IF: PC=00000134 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1895000] | IF: PC=00000134 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1905000] | IF: PC=00000138 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1915000] | IF: PC=0000013c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1925000] | IF: PC=00000140 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1935000] | IF: PC=00000144 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1945000] | IF: PC=00000144 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1955000] | IF: PC=00000144 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1965000] | IF: PC=00000144 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1975000] | IF: PC=00000144 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=1985000] | IF: PC=00000144 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=1995000] | IF: PC=00000148 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=2005000] | IF: PC=0000014c | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=2015000] | IF: PC=00000150 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=2025000] | IF: PC=00000154 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=2035000] | IF: PC=00000154 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=2045000] | IF: PC=00000154 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=2055000] | IF: PC=00000154 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=2065000] | IF: PC=00000154 | ID: 00000013 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
  PASS  addi x2=42            x2                    = 0x0000002a
  PASS  addi x3=99            x3                    = 0x00000063
  PASS  lw x4=42              x4                    = 0x0000002a
  PASS  add x5=42             x5                    = 0x0000002a
  FAIL  lw x6=99              x6   expected=0x00000063  got=0x00000000
  FAIL  sub x7=57             x7   expected=0x00000039  got=0xffffffd6
  PASS  sw x2->mem[100]       dcache[0x00000064] = 0x0000002a
  FAIL  sw x3->mem[104]       dcache[0x00000068]  expected=0x00000063  got=0x00000000

========== SUMMARY ==========
PASS: 5   FAIL: 3   TOTAL: 8
SOME TESTS FAILED -- check pipeline/forwarding/memory
core_riscv_tb.sv:278: $finish called at 2065000 (1ps)
```

Referencing the RISC-V assembly again:

```
32'h06400093; // addi x1, x0, 100    # passed
32'h02A00113; // addi x2, x0, 42     # passed
32'h0020A023; // sw   x2, 0(x1)      # passed
32'h06300193; // addi x3, x0, 99     # passed
32'h0030A223; // sw   x3, 4(x1)      # stored 0?
32'h0000A203; // lw   x4, 0(x1)      # passed
32'h000202B3; // add  x5, x4, x0     # load-use passed
32'h0040A303; // lw   x6, 4(x1)      # returned 0
32'h404303B3; // sub  x7, x6, x4     # became -42 since x6 got 0

---

x1 = 100
x2 = 42
x3 = 99
x4 = 42
x5 = 42
x6 = 0 
x7 = -42

mem[100] = 42
mem[104] = 0
```
We can observe a couple of issues by breaking down what we got compared to the ideal result. We can trace that the addi instructions for x1 and x2 worked as expected. Based on testbench 1, we were able to verify that forwarding is fine, so back-to-back addi/add instructions shouldn't cause issues even with RAW dependencies. The issue is the store instruction. We know x3 is 99, yet when we perform a store instruction to memory location 104, the value at that subsequent memory address is 0. When we perform a lw instruction to x6 from that same memory address, we get zero. But why? The issue can't be x3, but rather a more subtle structural bug.

- Did it get squashed along the pipeline because the next pipeline was still stalled? Could subtle cache timing mismatches cause the instruction to get lost? Is it encoded wrong? Did it write to a different cache line in the D-cache? I find the former to be a more convincing issue.

---

## Troubleshooting

Let's take a look at the pipeline trace. If we want to see whether it showed up in the pipeline at all, let's reference the hexadecimal value of the sw instruction which is `32'h0030A223` (sw x3, 4(x1)) at PC address 0x10. The previous instruction is `32'h06300193`, which was addi x3, x0, 99.

```
[T=135000] | IF: PC=00000004 | ID: 06400093 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=145000] | IF: PC=00000008 | ID: 06400093 | EX: rd=x1 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=155000] | IF: PC=0000000c | ID: 02a00113 | EX: rd=x1 mrd=0 mwr=0 | MEM: rd=x1 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=165000] | IF: PC=00000010 | ID: 0020a023 | EX: rd=x2 mrd=0 mwr=0 | MEM: rd=x1 mrd=0 mwr=0 mw=1 | WB: rd=x1 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=175000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=1 | MEM: rd=x2 mrd=0 mwr=0 mw=1 | WB: rd=x1 rw=1 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=0
[T=185000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x3 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x2 rw=1 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=195000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=205000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=215000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=225000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=0 dcache_rdy=0
[T=235000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=1 flush_idex=1 mem_stall=1 fetch_stall=1 dcache_rdy=0
[T=245000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x0 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=1 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=1 dcache_rdy=1
[T=255000] | IF: PC=00000014 | ID: 06300193 | EX: rd=x3 mrd=0 mwr=0 | MEM: rd=x0 mrd=0 mwr=0 mw=0 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
[T=265000] | IF: PC=00000018 | ID: 0000a203 | EX: rd=x3 mrd=0 mwr=0 | MEM: rd=x3 mrd=0 mwr=0 mw=1 | WB: rd=x0 rw=0 | stall=0 flush_idex=0 mem_stall=0 fetch_stall=0 dcache_rdy=0
```

Another hypothesis that could be the issue; maybe the S-type formatting might give it issues for detecting a RAW hazard here. We had an addi instruction that hasn't retired by the time that store instruction is supposed to execute, which could be why the store sees a stale value of x3 (0 instead of 99).

---



