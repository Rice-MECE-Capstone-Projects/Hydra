class mmr_rw_sequence extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(mmr_rw_sequence)
    
    function new(string name="mmr_rw_sequence");
        super.new(name);
    endfunction

    virtual task body;
        cpu_ahb_transaction tr;

        logic [31:0] addresses[3]='{
            32'h0000_0004,//SRC
            32'h0000_0008,//DST
            32'h0000_000C//LEN
        };

        logic [31:0] values[3]='{
            32'h8000_0000,
            32'h0000_0100,
            32'h0000_0010
        };

        //write 3 registers
        for(int i=0;i<3;i++)begin
            tr=cpu_ahb_transaction::type_id::create($sformatf("write_tr_%0d",i));
            start_item(tr);
            tr.direction=AHB_WRITE;
            tr.address=addresses[i];
            tr.write_data=values[i];
            finish_item(tr);

            if(tr.response!=1'b0)
                `uvm_error("WRITE_RESPONSE","Register write failed")
        end

        //read 3 registers
        for(int i=0;i<3;i++)begin
            tr=cpu_ahb_transaction::type_id::create($sformatf("read_tr_%0d",i));

            start_item(tr);
            tr.direction=AHB_READ;
            tr.address=addresses[i];
            finish_item(tr);

            if(tr.response!==1'b0)begin
                `uvm_error("READ_RESPONSE","Register read failed")
            end
            else if (tr.read_data!==values[i])begin
                `uvm_error("SEQ_READBACK",$sformatf("Address=0x%08h expected=0x%08h actual=0x%08h",addresses[i],values[i],tr.read_data))
            end
        end
    endtask
endclass
        



