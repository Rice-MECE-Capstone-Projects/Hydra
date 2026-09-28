//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ram_transaction.sv
//
// Author: Yulia Zhou
//
// Description:
// Records one completed RAM read observed on the Transform interface.
// Contains the request address and the returned data and response.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ram_transaction extends uvm_sequence_item;

    // Observed request and response
    logic [hydra_pkg::ADDR_WIDTH-1:0] address;
    logic [hydra_pkg::DATA_WIDTH-1:0] read_data;
    logic response;

    `uvm_object_utils_begin(transform_ram_transaction)
        `uvm_field_int(address, UVM_HEX)
        `uvm_field_int(read_data, UVM_HEX)
        `uvm_field_int(response, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name="transform_ram_transaction");
        super.new(name);
    endfunction

endclass