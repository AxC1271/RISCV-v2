`timescale 1ns / 1ps

module data_memory_tb();

    logic clk;
    logic rst_n;
    logic [31:0] mem_addr;
    logic [31:0] wr_data;
    logic [31:0] rd_data;
    logic MemWrite;
    logic MemRead;
    
    // instantiate the DUT
    data_memory # (
        .DEPTH(256)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .MemWrite(MemWrite),
        .MemRead(MemRead)
    );
    
    // 100MHz clk generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // test stimulus
    initial begin
        rst_n = 0;
        mem_addr = 0;
        wr_data = 0;
        MemWrite = 0;
        MemRead = 0;
        
        // display header
        $display("=== Data Memory Testbench ===");
        $display("Time\tAddr\tWrite\tRead\tData");
        
        // test 1: reset
        #10;
        rst_n = 1;
        #10;
        $display("reset complete");
        
        // test 2: write to address 0x00
        $display("\n--- Test 2: write to address 0x00 ---");
        mem_addr = 32'h00000000;
        wr_data = 32'hDEADBEEF;
        MemWrite = 1;
        MemRead = 0;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, wr_data);
        MemWrite = 0;
        
        // test 3: read from address 0x00
        $display("\n--- Test 3: Read from address 0x00 ---");
        mem_addr = 32'h00000000;
        MemRead = 1;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, rd_data);
        assert(rd_data == 32'hDEADBEEF) else $error("Read mismatch! Expected 0xDEADBEEF, got 0x%h", rd_data);
        MemRead = 0;
        
        // test 4: write to address 0x04 (word 1)
        $display("\n--- Test 4: Write to address 0x04 ---");
        mem_addr = 32'h00000004;
        wr_data = 32'hCAFEBABE;
        MemWrite = 1;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, wr_data);
        MemWrite = 0;
        
        // test 5: read from address 0x04
        $display("\n--- Test 5: Read from address 0x04 ---");
        mem_addr = 32'h00000004;
        MemRead = 1;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, rd_data);
        assert(rd_data == 32'hCAFEBABE) else $error("Read mismatch! Expected 0xCAFEBABE, got 0x%h", rd_data);
        MemRead = 0;
        
        // test 6: write multiple sequential addresses
        $display("\n--- Test 6: Sequential writes ---");
        for (int i = 0; i < 10; i++) begin
            mem_addr = i * 4;  // Word-aligned addresses (0, 4, 8, 12, ...)
            wr_data = 32'h1000_0000 + i;
            MemWrite = 1;
            #10;
            $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, wr_data);
        end
        MemWrite = 0;
        
        // test 7: read back sequential addresses
        $display("\n--- Test 7: Sequential reads ---");
        for (int i = 0; i < 10; i++) begin
            mem_addr = i * 4;
            MemRead = 1;
            #10;
            $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, rd_data);
            assert(rd_data == (32'h1000_0000 + i)) else 
                $error("Read mismatch at addr 0x%h! Expected 0x%h, got 0x%h", 
                       mem_addr, 32'h1000_0000 + i, rd_data);
        end
        MemRead = 0;
        
        // test 8: write and read at boundary (address 0x3FC = word 255)
        $display("\n--- Test 8: Boundary test (max address) ---");
        mem_addr = 32'h000003FC;  // Last word (255 * 4 = 1020 = 0x3FC)
        wr_data = 32'hFFFFFFFF;
        MemWrite = 1;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, wr_data);
        MemWrite = 0;
        
        mem_addr = 32'h000003FC;
        MemRead = 1;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, rd_data);
        assert(rd_data == 32'hFFFFFFFF) else $error("Boundary read failed!");
        MemRead = 0;
        
        // test 9: verify old data still intact
        $display("\n--- Test 9: Verify address 0x00 unchanged ---");
        mem_addr = 32'h00000000;
        MemRead = 1;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, rd_data);
        assert(rd_data == 32'hDEADBEEF) else $error("Data corruption detected!");
        MemRead = 0;
        
        // test 10: reset and verify memory cleared
        $display("\n--- Test 10: Reset clears memory ---");
        rst_n = 0;
        #10;
        rst_n = 1;
        #10;
        mem_addr = 32'h00000000;
        MemRead = 1;
        #10;
        $display("%0t\t0x%h\t%b\t%b\t0x%h", $time, mem_addr, MemWrite, MemRead, rd_data);
        assert(rd_data == 32'h0) else $error("Memory not cleared after reset!");
        
        #20;
        $display("\n=== All tests passed! ===");
        $finish;
    end
    
    // timeout watchdog
    initial begin
        #10000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule