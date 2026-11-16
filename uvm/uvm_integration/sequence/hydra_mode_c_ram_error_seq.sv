class hydra_mode_c_ram_error_seq extends hydra_mode_c_basic_seq;
    `uvm_object_utils(hydra_mode_c_ram_error_seq)

    bit irq_seen=0;
    bit status_error_seen=0;

    function new(string name="hydra_mode_c_ram_error_seq");
        super.new(name);
    endfunction

    virtual task body();
        logic [31:0] data;
        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")

        ahb_access(1, 32'h2000_0004,32'h8000_0000,data); //SRC
        ahb_access(1, 32'h2000_0008,32'h2001_0000,data); //DST
        ahb_access(1, 32'h2000_000C,32'd4,data); //LEN
        ahb_access(1, 32'h2000_0000,32'h0000_0107,data); //Mode C+START

        for(int i=0;i<1000;i++)begin
            @(cpu_vif.driver_cb);
            if(cpu_vif.irq_hydra===1'b1)begin
                irq_seen=1;
                break;
            end
        end

        if(!irq_seen)begin
            `uvm_error("ERROR_IRQ","No completion/error interrupt observed")
            return;
        end

        ahb_access(0, 32'h2000_0010,'0,data); // STATUS
        status_error_seen=(data===32'h0000_0001);

        if(!status_error_seen)
            `uvm_error("ERROR_STATUS",$sformatf("Expected STATUS=1 after RAM error, got 0x%08h", data))
    endtask
endclass
