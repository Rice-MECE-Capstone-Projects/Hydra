class hydra_mode_c_random_seq extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(hydra_mode_c_random_seq)

    virtual cpu_ahb_if cpu_vif;

    logic [31:0] sample_words[];
    logic [31:0] source_address;
    logic [31:0] destination_address;
    int unsigned transfer_length;
    int unsigned shift_amount;
    bit signed_output;
    bit round_enable;
    bit failed=0;

    function new(string name="hydra_mode_c_random_seq");
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

    // Reference calculation
    function automatic logic [7:0] predict_byte(logic [31:0] raw);
        longint signed value;
        value=$signed(raw);
        if(round_enable && shift_amount!=0)
            value+=64'sd1<<(shift_amount-1);
        value=value>>>shift_amount;

        if(signed_output)begin
            if(value>127) value=127;
            else if (value<-128) value=-128;
        end
        else begin
            if(value>255) value=255;
            else if (value<0) value=0;
        end

        return value[7:0];
    endfunction

    virtual task body();
        logic [31:0] data;
        logic [31:0] expected_word;
        logic [31:0] ctrl_value;
        bit irq_seen=0;

        if(cpu_vif==null)
            `uvm_fatal("NO_VIF","CPU interface is missing")
        
        ctrl_value = '0;
        ctrl_value[0] = 1'b1;   // START
        ctrl_value[2:1] = 2'b11; //Mode C
        ctrl_value[7:3] = shift_amount;
        ctrl_value[8] = signed_output;
        ctrl_value[9] = round_enable;

        ahb_access(1, 32'h2000_0004, source_address,data);
        ahb_access(1, 32'h2000_0008, destination_address,data);
        ahb_access(1, 32'h2000_000C, transfer_length, data);
        ahb_access(1, 32'h2000_0000, ctrl_value, data);

        for(int i=0;i<1000;i++)begin
            @(cpu_vif.driver_cb);
            if(cpu_vif.irq_hydra===1'b1)begin
                irq_seen=1;
                break;
            end
        end

        if(!irq_seen)
            `uvm_fatal("TIMEOUT","Mode C did not finish")
        
        ahb_access(0, 32'h2000_0010,'0,data);
        if(data!==32'h0)begin
            `uvm_error("STATUS",$sformatf("Expected 0, got 0x%08h", data))
            failed=1;
        end

        for(int w=0; w<transfer_length/4;w++)begin
            expected_word='0;
            for(int b=0;b<4;b++)
                expected_word[8*b+:8]=predict_byte(sample_words[4*w+b]);
            
            ahb_access(0,destination_address+4*w,'0,data);
            if(data!==expected_word)begin
                `uvm_error("MODE_C_RESULT",$sformatf("Word %0d: expected 0x%08h, got 0x%08h", w, expected_word, data))
                failed=1;
            end
        end
    endtask
endclass

