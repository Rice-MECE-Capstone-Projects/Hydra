//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ram_model.sv
//
// Author: Yulia Zhou
//
// Description:
// Stores 32-bit input words indexed by byte address.
// Tests preload input data before starting Transform.
// The RAM responder reads this model to generate bus responses.
//
// Scope:
// Supports aligned 32-bit words for the initial Transform tests.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ram_model extends uvm_object;
    `uvm_object_utils(transform_ram_model)

    typedef bit [hydra_pkg::ADDR_WIDTH-1:0] addr_t;
    typedef logic [hydra_pkg::DATA_WIDTH-1:0] data_t;

    // associative array: byte address -> data word
    protected data_t memory[addr_t];

    function new(string name="transform_ram_model");
        super.new(name);
    endfunction

    // called by the test to prepare input data
    function void write_word(addr_t address, data_t data);
        if(address[1:0]!=2'b00)begin
            `uvm_fatal("RAM_ALIGNMENT",$sformatf("Unaligned preload address: 0x%08h",address))
        end
        memory[address]=data;
    endfunction

    // called by the RAM responder
    function data_t read_word (addr_t address);
        if(address[1:0]!=2'b00)begin
            `uvm_fatal("RAM_ALIGNMENT",$sformatf("Unaligned read address:0x%08h",address))
            return 'x;
        end

        if(!memory.exists(address))begin
            `uvm_fatal("RAM_UNINITIALIZED",$sformatf("No input data prepared at address 0x%08h",address))
            return 'x;
        end

        return memory[address];
    endfunction

endclass