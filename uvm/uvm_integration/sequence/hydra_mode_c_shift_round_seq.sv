class hydra_mode_c_shift_round_seq extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(hydra_mode_c_shift_round_seq)

    virtual cpu_ahb_if cpu_vif;

    function new(string name="hydra_mode_c_shift_round_seq");
        super.new(name);
    endfunction

    task automatic ahb_access(
        input bit write,
        input logic [31:0] addr,
        input logic [31:0] wdata,
        output logic [31:0] rdata
    );
        cpu_ahb_transaction tr;

        tr=cpu_ahb_transaction::type_id::create("tr");
        start_item(tr);
        tr.direction=write?AHB_WRITE:AHB_READ;
        tr.address=addr;
        tr.write_data=wdata;
        finish_item(tr);

        if(tr.response!==1'b0)
            `uvm_fatal("AHB_ERROR",$sformatf("Access failed at 0x%08h",addr))
        rdata=tr.read_data;
    endtask

    virtual task body();
        logic [31:0] data;
        logic [31:0] expected;
        bit irq_seen=0;
        bit failed=0;

        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")
        ahb_access(1,32'h2000_0004,32'h8000_0000,data); // SRC
        ahb_access(1,32'h2000_0008,32'h2001_0000,data); // DST
        ahb_access(1,32'h2000_000C,32'd8,data); // LEN
        ahb_access(1,32'h2000_0000,32'h0000_030F,data); // round=1 signed=1 shift=1 Mode C START

        for(int i=0;i<1000;i++)begin
            @(cpu_vif.driver_cb);
            if(cpu_vif.irq_hydra===1'b1)begin
                irq_seen=1;
                break;
            end
        end

        if(!irq_seen)
         `uvm_fatal("TIMEOUT","Mode C didn't finish")

        ahb_access(0,32'h2000_0010,'0,data); // STATUS
        if(data!==32'h0)begin
            `uvm_error("STATUS",$sformatf("Expected 0, got 0x%08h",data))
            failed=1;
        end

        for(int w=0;w<2;w++)begin
            expected=(w==0)?32'h0201_0100:32'h0403_0302;
            ahb_access(0,32'h2001_0000+4*w,'0,data);

            if(data!==expected)begin
                `uvm_error("MODE_C_RESULT",$sformatf("Word %0d: expected 0x%08h, got 0x%08h",w,expected,data))
                failed=1;
                end
        end

        if(!failed)
            `uvm_info("PASS","Mode C shift/round integration: both output words matched",UVM_LOW)
    endtask
endclass
