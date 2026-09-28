class mmr_src_sequence extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils (cpu_ahb_sequence)

    function new(string name="mmr_src_sequence");
        super.new(name);
    endfunction

    virtual task body();
        cpu_ahb_transaction tr;

        //write SRC register
        tr = cpu_ahb_transaction::type_id::create("write_src_tr");

        start_item(tr);

        tr.direction = AHB_WRITE;
        tr.address = 32'h0000_0004;
        tr.write_data = 32'h8000_0000;

        finish_item(tr);

        //read SRC register
        tr = cpu_ahb_transaction::type_id::create("read_src_tr");

        start_item(tr);

        tr.direction = AHB_READ;
        tr.address = 32'h0000_0004;

        finish_item(tr);

        //check read result
        if(tr.response != 1'b0)begin
            `uvm_error("AHB_RESPONSE", "MMR returned an AHB error response")
        end
        else if (tr.read_data!==32'h8000_0000)begin
            `uvm_error("SRC_READBACK",$sformatf("Expected SRC=0x80000000, actual=0x%08h",tr.read_data))
        end
        else begin
            `uvm_info("SRC_READBACK","SRC register write/read test passed",UVM_LOW)
        end
    
    endtask
endclass