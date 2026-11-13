class hydra_mode_b_two_block_seq extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(hydra_mode_b_two_block_seq)
    
    virtual cpu_ahb_if cpu_vif;

    function new(string name="hydra_mode_b_two_block_seq");
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
        logic [31:0] expected_data;
        int unsigned block_size;
        int unsigned local_index;
        int unsigned input_index;
        bit irq_seen=0;
        bit failed=0;

        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")
        
        block_size=hydra_pkg::BLOCK_ROWS*hydra_pkg::BLOCK_COLS;

        ahb_access(1,32'h2000_0004,32'h8000_0000,data);
        ahb_access(1,32'h2000_0008,32'h2001_0000,data);
        ahb_access(1,32'h2000_000C,2*block_size,data);
        ahb_access(1,32'h2000_0000,32'h0000_0005,data);

        for(int i=0;i<1000;i++)begin
            @(cpu_vif.driver_cb);
            if(cpu_vif.irq_hydra===1'b1)begin
                irq_seen=1;
                break;
            end
        end

        if(!irq_seen)
            `uvm_fatal("TIMEOUT","Mode B didn't finish")
        
        ahb_access(0,32'h2000_0010,'0,data);
        if(data!==32'h0)begin
            `uvm_error("STATUS",$sformatf("Expected 0, got 0x%08h", data))
            failed=1;
        end

        for(int j=0;j<2*block_size;j++)begin
            local_index=j%block_size;

            // Transpose within the current 128-word block
            input_index=(j/block_size)*block_size+(local_index%hydra_pkg::BLOCK_ROWS)*hydra_pkg::BLOCK_COLS+(local_index/hydra_pkg::BLOCK_ROWS);
            expected_data=input_index+1;

            ahb_access(0,32'h2001_0000+4*j,'0,data);

            if(data!==expected_data)begin
                `uvm_error("MODE_B_RESULT",$sformatf("Output %0d: expected 0x%08h, got 0x%08h", j, expected_data,data))
                failed=1;
                break;
            end
        end

        if(!failed)
            `uvm_info("PASS","Mode B two-block integration: all 256 outputs matched",UVM_LOW)
    endtask
endclass