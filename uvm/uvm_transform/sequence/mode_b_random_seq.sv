class mode_b_random_seq extends uvm_sequence #(transform_ctrl_transaction);
    `uvm_object_utils(mode_b_random_seq)

    int unsigned transfer_length;
    bit [hydra_pkg::ADDR_WIDTH-1:0] source_address=32'h8000_0000;
    bit [hydra_pkg::ADDR_WIDTH-1:0] destination_address='0;

    function new(string name="mode_b_random_seq");
        super.new(name);
    endfunction

    virtual task body();
        transform_ctrl_transaction tr;
        tr=transform_ctrl_transaction::type_id::create("tr");

        start_item(tr);
        tr.mode=hydra_pkg::MODE_B;
        tr.src_addr=source_address;
        tr.dst_addr=destination_address;
        tr.length=transfer_length;
        tr.scale_shift='0;
        tr.signed_out=1'b0;
        tr.round_en=1'b0;
        finish_item(tr);
    endtask
endclass