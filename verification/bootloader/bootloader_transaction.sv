class bootloader_transaction extends uvm_sequence_item;
    `uvm_object_utils_begin(bootloader_transaction)
        `uvm_field_array_int(program, UVM_ALL_ON)
        `uvm_field_int(start_addr, UVM_ALL_ON)
        `uvm_field_int(boot_done, UVM_ALL_ON)
        `uvm_field_int(boot_error, UVM_ALL_ON)
    `uvm_object_utils_end
    
    // inputs
    rand bit [31:0] program[];  
    rand bit [31:0] start_addr;     
    
    // output flags
    bit boot_done;
    bit boot_error;
    
    // constraints
    constraint reasonable_size {
        program.size() inside {[1:256]};  
    }
    
    constraint valid_address {
        start_addr[1:0] == 2'b00;  
        start_addr < 32'h1000;      
    }
    
    function new(string name = "bootloader_transaction");
        super.new(name);
    endfunction
endclass