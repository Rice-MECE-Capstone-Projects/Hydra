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

    function new(string name="mode_c_basic_seq");
        super.new(name);
    endfunction

    virtual task body();
        transform_ctrl_transaction tr;
        tr=transform_ctrl_transaction::type_id::create("tr");

        start_item(tr);
        tr.mode=hydra_pkg::MODE_C;
        tr.src_addr=32'h8000_0000;
        tr.dst_addr=32'h0000_0000;
        tr.length=4;
        tr.scale_shift=0;
        tr.signed_out=1'b1;
        tr.round_en=1'b0;
        finish_item(tr);
    endtask
endclass

    