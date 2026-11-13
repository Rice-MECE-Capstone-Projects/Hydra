class hydra_invalid_length_seq extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(hydra_invalid_length_seq)

    virtual cpu_ahb_if cpu_vif;
    int mode_number; //2=Mode B, 3=Mode C

    function new(string name="hydra_invalid_length_seq");
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
        logic [31:0] ctrl_value;
        logic [31:0] invalid_length;
        bit error_seen=0;

        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")
        
        if(mode_number==2)begin
            ctrl_value=32'h0000_0005; //Mode B+start
            invalid_length=64;
        end
        else if (mode_number==3)begin
            ctrl_value=32'h0000_0007; //Mode C+start
            invalid_length=3;
        end
        else 
            `uvm_fatal("TEST_CONFIG","mode_number must be 2 or 3")
        
        ahb_access(1,32'h2000_0004,32'h8000_0000,data);
        ahb_access(1,32'h2000_0008,32'h2001_0000,data);
        ahb_access(1,32'h2000_000C,invalid_length,data);
        ahb_access(1,32'h2000_0000,ctrl_value,data);

        // STATUS[0] is sticky, so polling will not miss a short error pulse
        for(int i=0;i<20;i++)begin
            ahb_access(0,32'h2000_0010,'0,data);
            if(data===32'h0000_0001)begin
                error_seen=1;
                break;
            end
        end

        if(!error_seen)begin
            `uvm_error("STATUS",$sformatf("Expected STATUS=1 for invalid length,last read=0x%08h", data))
            return;
        end

        // Writing STATUS clears the sticky error bit
        ahb_access(1,32'h2000_0010,32'h0,data); // write
        ahb_access(0,32'h2000_0010,'0,data); // read

        if(data!==32'h0)
            `uvm_error("STATUS_CLEAR",$sformatf("Expected STATUS=0 after clearing, got 0x%08h",data))
        else
            `uvm_info("STATUS_CLEAR","Sticky error bit cleared and read back",UVM_LOW)
    endtask
endclass

