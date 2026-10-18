//////////////////////////////////////////////////////////////////////////////////////////////////
// File: mode_c_basic_seq.sv
//
// Author: Yulia Zhou
//
// Description:
// Configures one Mode C operation with four input words,
// signed output, no scaling, and no rounding.
// Input data must be prepared separately in the RAM model.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class mode_c_basic_seq extends uvm_sequence #(transform_ctrl_transaction);
    `uvm_object_utils(mode_c_basic_seq)

    bit [hydra_pkg::DATA_BITS-1:0] shift_amount='0;
    bit [hydra_pkg::LEN_WIDTH-1:0] transfer_length=4;
    bit [hydra_pkg::ADDR_WIDTH-1:0] source_address=32'h8000_0000;
    bit [hydra_pkg::ADDR_WIDTH-1:0] destination_address=32'h0000_0000;
    bit round_enable=1'b0;
    bit signed_output=1'b1;

    function new(string name="mode_c_basic_seq");
        super.new(name);
    endfunction

    virtual task body();
        transform_ctrl_transaction tr;
        tr=transform_ctrl_transaction::type_id::create("tr");

        start_item(tr);
        tr.mode=hydra_pkg::MODE_C;
        tr.src_addr=source_address;
        tr.dst_addr=destination_address;
        tr.length=transfer_length;
        tr.scale_shift=shift_amount;
        tr.signed_out=signed_output;
        tr.round_en=round_enable;
        finish_item(tr);
    endtask
endclass

    