`timescale 1ns / 1ps

module program_counter_tb();
    // necessary dut signals
    logic clk;
    logic pc_in;
    logic pc_out;

    // generate a 100MHz clock here
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // instantiate dut 
    dut program_counter (
        .clk(clk),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

endmodule