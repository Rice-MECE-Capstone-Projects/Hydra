class hydra_mode_c_basic_seq extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils (hydra_mode_c_basic_seq)

    virtual cpu_ahb_if cpu_vif;

    function new(string name="hydra_mode_c_basic_seq");
        super.new(name);
    endfunction

    task automatic ahb_access(
        bit write,
        logic [31:0] addr,
        logic [31:0] wdata,
        output logic [31:0] rdata
    );
        cpu_ahb_transaction tr;
        tr=cpu_ahb_transaction::type_id::create("tr");
        start_item(tr);
        tr.direction = write?AHB_WRITE:AHB_READ;
        tr.address=addr;
        tr.write_data=wdata;
        finish_item(tr);

        if(tr.response!==1'b0)
            `uvm_fatal("AHB_ERROR",$sformatf("Access failed at 0x%08h",addr))
        rdata=tr.read_data;
    endtask

    virtual task body();
        logic [31:0] data;
        bit irq_seen=0;

        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")

        ahb_access(1,32'h2000_0004,32'h8000_0000,data);//SRC
        ahb_access(0, 32'h2000_0004, '0, data); // read back SRC
        if(data!==32'h8000_0000)
            `uvm_error("SRC_READBACK",$sformatf("Expected 0x80000000, got 0x%08h", data))
        ahb_access(1,32'h2000_0008,32'h2001_0000,data);//DST
        ahb_access(0,32'h2000_0008,'0,data);//Read back DST
        if(data!==32'h2001_0000)
            `uvm_error("DST_READBACK",$sformatf("Expected 0x20010000,got 0x%08h",data))
        ahb_access(1,32'h2000_000C,32'd4,data);//LEN
        ahb_access(0,32'h2000_000C,'0,data);
        if(data!==32'd4)
            `uvm_error("LEN_READBACK",$sformatf("Expected 4, got %0d",data))
        
        ahb_access(1,32'h2000_0000,32'h0000_0106,data); //Mode C, signed, NO START
        ahb_access(0,32'h2000_0000,'0,data);
        if(data!==32'h0000_0106)
            `uvm_error("CTRL_READBACK",$sformatf("Expected 0x00000106, got 0x%08h",data))
        ahb_access(1,32'h2000_0000,32'h0000_0107,data);//Mode C + START

        for(int i=0;i<1000;i++)begin
            @(cpu_vif.driver_cb);
            if(cpu_vif.irq_hydra===1'b1)begin
                irq_seen=1;
                break;
            end
        end

        if(!irq_seen)
            `uvm_fatal("TIMEOUT","HYDRA did not finish")
        
        ahb_access(0,32'h2000_0010,'0,data); // STATUS
        if(data!==32'h0)
            `uvm_error("STATUS",$sformatf("Expected 0, got 0x%08h", data))

        ahb_access(0,32'h2001_0000,'0,data); // scratchpad
        if(data!==32'h0403_0201)
            `uvm_error("RESULT",$sformatf("Expected 0x04030201,got 0x%08h",data))
        else
            `uvm_info("PASS","Mode C integration result matched",UVM_LOW)
    endtask
endclass



