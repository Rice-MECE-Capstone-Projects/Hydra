//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ctrl_transaction.sv
//
// Author: Yulia Zhou
//
// Description:
// Describes the configuration of one Transform operation,
// including mode, addresses, input length, and quantization settings.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////
class transform_ctrl_transaction extends uvm_sequence_item;

    // Configuration fields
    rand hydra_pkg::hydra_mode mode;
    rand bit [hydra_pkg::ADDR_WIDTH-1:0] src_addr;
    rand bit [hydra_pkg::ADDR_WIDTH-1:0] dst_addr;
    rand bit [hydra_pkg::LEN_WIDTH-1:0] length;

    rand bit [hydra_pkg::DATA_BITS-1:0] scale_shift;
    rand bit signed_out;
    rand bit round_en;

    // Factory registration and field automation
    `uvm_object_utils_begin(transform_ctrl_transaction)
        `uvm_field_enum(hydra_pkg::hydra_mode,mode,UVM_DEFAULT)
        `uvm_field_int(src_addr,UVM_HEX)
        `uvm_field_int(dst_addr,UVM_HEX)
        `uvm_field_int(length,UVM_DEC)
        `uvm_field_int(scale_shift,UVM_DEC)
        `uvm_field_int(signed_out,UVM_DEFAULT)
        `uvm_field_int(round_en,UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name="transform_ctrl_transaction");
        super.new(name);
    endfunction

endclass

    