.section .text.startup
    .global _start
    .type _start, @function

_start:
    la sp, _stack_top

    la a0, _data_load
    la a1, _data_start
    la a2, _data_end

copy_loop:
    bge a1, a2, copy_done
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j copy_loop

copy_done:
    la a0, _bss_start
    la a1, _bss_end

bss_loop:
    bge a0, a1, bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j bss_loop

bss_done:
    call main

hang:
    j hang

    .size _start, . - _start