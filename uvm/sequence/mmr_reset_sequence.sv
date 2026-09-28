class mmr_reset_sequence extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(mmr_reset_sequence)

    function new(string name="mmr_reset_sequence");
        super.new(name);
    endfunction

    virtual task body();
        cpu_ahb_transaction tr;

        logic [31:0] addresses[3]='{
            32'h0000_0004,
            32'h0000_0008,
            32'h0000_000C
        };

        for(int i=0; i<3; i++)begin
            tr=cpu_ahb_transaction::type_id::create($sformatf("reset_read_%0d",i));

            start_item(tr);
            tr.direction=AHB_READ;
            tr.address = addresses[i];
            finish_item(tr);

            if(tr.response!==1'b0)begin
                `uvm_error("RESET_RESPONSE","Read response failed")
            end
            else if(tr.read_data !== 32'h0000_0000)begin
                `uvm_error("RESET_VALUE",$sformatf("Address=0x%08h expected=0 actual=0x%08h",addresses[i],tr.read_data))
            end
        end
    endtask

endclass