//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_scratch_transaction.sv
//
// Author: Yulia Zhou
//
// Description:
// Records the address and data of one scratchpad write observed at the output of hydra_transform.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_scratch_transaction extends uvm_sequence_item;
    logic [hydra_pkg::ADDR_WIDTH-1:0] address;
    logic [hydra_pkg::DATA_WIDTH-1:0] write_data;

    `uvm_object_utils_begin(transform_scratch_transaction)
        `uvm_field_int(address,UVM_HEX)
        `uvm_field_int(write_data,UVM_HEX)
    `uvm_object_utils_end

    function new(string name="transform_scratch_transaction");
        super.new(name);
    endfunction

endclass