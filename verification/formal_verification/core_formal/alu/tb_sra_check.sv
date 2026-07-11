module tb_sra_check;

    logic [31:0] a, b;
    logic [3:0]  alu_opcode;
    logic [31:0] res;

    alu dut (.a(a), .b(b), .alu_opcode(alu_opcode), .res(res));

    initial begin
        a = 32'hfb7db6d0;
        b = 32'hff8038c9;
        alu_opcode = 4'b0111; // ALU_SRA
        #1;
        $display("a          = %h (signed %0d)", a, $signed(a));
        $display("b[4:0]     = %0d", b[4:0]);
        $display("res (RTL)  = %h", res);
        $display("expected   = fffdbedb");
        if (res === 32'hfffdbedb)
            $display("MATCH: RTL computed the correct value. This is a Yosys/formal tooling artifact, not an RTL bug.");
        else
            $display("MISMATCH: RTL itself is wrong. Real bug, not a tooling artifact.");
        $finish;
    end

endmodule