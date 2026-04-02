# Branch penalty test
# BEQ is taken (x1 == x1), causing a 2-cycle flush.
# Verify that the instructions at PC+4 and PC+8 are squashed (become NOPs in waveform).

    addi  x1, x0, 5       # x1 = 5
    addi  x2, x0, 5       # x2 = 5
    beq   x1, x2, target  # branch taken -> flush IF/ID, ID/EX
    addi  x3, x0, 99      # SQUASHED (should appear as NOP in waveform)
    addi  x4, x0, 88      # SQUASHED
target:
    addi  x5, x0, 1       # x5 = 1  (first instruction after branch resolves)
    addi  x6, x0, 2       # x6 = 2