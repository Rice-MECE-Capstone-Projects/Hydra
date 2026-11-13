class hydra_mode_b_random_seq extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(hydra_mode_b_random_seq)

    virtual cpu_ahb_if cpu_vif;
    logic [31:0] sample_words[256];
    logic [31:0] source_address;
    logic [31:0] destination_address;
    int unsigned transfer_length;
    bit failed=0;


    function new(string name="hydra_mode_b_random_seq");
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
        int block_index;
        int local_index;
        int row;
        int col;
        int input_index;
        bit irq_seen=0;

        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")

        ahb_access(1,32'h2000_0004,source_address,data);
        ahb_access(1,32'h2000_0008,destination_address,data);
        ahb_access(1,32'h2000_000C,transfer_length,data);
        ahb_access(1,32'h2000_0000,32'h0000_0005,data);

        for(int i=0;i<2000;i++)begin
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
            `uvm_error("STATUS",$sformatf("Expected 0, got 0x%08h",data))
            failed=1;
        end

        for(int j=0;j<transfer_length;j++)begin
            block_index=j/128;
            local_index=j%128;
            row=local_index%hydra_pkg::BLOCK_ROWS;
            col=local_index/hydra_pkg::BLOCK_ROWS;
            input_index = block_index*128+row*hydra_pkg::BLOCK_COLS+col;
            expected=sample_words[input_index];

            ahb_access(0,destination_address+4*j,'0,data);
            if(data!==expected)begin
                `uvm_error("MODE_B_RESULT",$sformatf("Output %0d: expected 0x%08h,got 0x%08h",j,expected,data))
                failed=1;
                end
        end
    endtask
endclass


