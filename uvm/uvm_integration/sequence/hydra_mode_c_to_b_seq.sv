class hydra_mode_c_to_b_seq extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(hydra_mode_c_to_b_seq)

    virtual cpu_ahb_if cpu_vif;
    bit failed=0;

    function new(string name="hydra_mode_c_to_b_seq");
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
            `uvm_fatal("AHB_ERROR",$sformatf("Access failed at 0x%08h", addr))
        rdata=tr.read_data;
    endtask

    task automatic wait_for_irq(string operation_name);
        bit seen=0;
        for(int i=0;i<1000;i++)begin
            @(cpu_vif.driver_cb);
            if(cpu_vif.irq_hydra===1'b1)begin
                seen=1;
                break;
            end
        end

        if(!seen)
            `uvm_fatal("TIMEOUT",$sformatf("%s didn't finish",operation_name))
    endtask

    task automatic wait_for_irq_low();
        for(int i=0;i<20;i++)begin
            @(cpu_vif.driver_cb);
            if(cpu_vif.irq_hydra===1'b0)
                return;
        end

        `uvm_fatal("IRQ_STUCK","IRQ did not return low after Mode C")
    endtask

    virtual task body();
        logic [31:0] data;
        logic [31:0] expected;
        int input_index;

        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")
        
        // First operation: Mode C
        ahb_access(1, 32'h2000_0004, 32'h8000_0000, data);
        ahb_access(1, 32'h2000_0008, 32'h2001_0000, data);
        ahb_access(1, 32'h2000_000C, 32'd4, data);
        ahb_access(1, 32'h2000_0000, 32'h0000_0107, data);

        wait_for_irq("Mode C");

        ahb_access(0, 32'h2000_0010,'0,data);
        if(data!==32'h0)begin
            `uvm_error("C_STATUS",$sformatf("Expected 0, got 0x%08h", data))
            failed=1;
        end

        ahb_access(0, 32'h2001_0000,'0,data);
        if(data!==32'h0403_0201)begin
            `uvm_error("C_RESULT",$sformatf("Expected 0x04030201, got 0x%08h", data))
            failed=1;
        end

        // Do not mistake the first operation's IRQ for the second one's
        wait_for_irq_low();

        // Second operation: Mode B
        ahb_access(1,32'h2000_0004, 32'h8000_0100, data);
        ahb_access(1,32'h2000_0008, 32'h2001_0100, data);
        ahb_access(1,32'h2000_000C, 32'd128,data);
        ahb_access(1,32'h2000_0000, 32'h0000_0005, data);

        wait_for_irq("Mode B");

        ahb_access(0,32'h2000_0010,'0,data);
        if(data!==32'h0)begin
            `uvm_error("B_STATUS", $sformatf("Expected 0, got 0x%08h", data))
            failed=1;
        end

        // check every word of the transposed Mode B block
        for(int j=0;j<hydra_pkg::BLOCK_ROWS*hydra_pkg::BLOCK_COLS;j++)begin
            input_index =(j % hydra_pkg::BLOCK_ROWS) * hydra_pkg::BLOCK_COLS+ (j / hydra_pkg::BLOCK_ROWS);
            expected = input_index + 1;

            ahb_access(0,32'h2001_0100+4*j,'0,data);
            if(data!==expected)begin
                `uvm_error("B_RESULT",$sformatf("Output %0d: expected 0x%08h, got 0x%08h",j,expected,data))
                failed=1;
            end
        end

        // Mode B must not overwrite Mode C's separate output address
        ahb_access(0,32'h2001_0000,'0,data);
        if(data!==32'h0403_0201)begin
            `uvm_error("C_OVERWRITEN",$sformatf("Mode C output changed to 0x%08h",data))
            failed=1;
        end

        if(!failed)
            `uvm_info("PASS", "Mode C followed by Mode B matched",UVM_LOW)
    endtask
endclass
