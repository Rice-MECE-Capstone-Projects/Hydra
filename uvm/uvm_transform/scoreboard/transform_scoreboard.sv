//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_scoreboard.sv
//
// Author: Yulia Zhou
//
// Description:
// Receives configuration, RAM read, and scratchpad write transactions.
// Stores copies of the observed transactions for Mode C checking.
//
// Scope:
// Reception framework for one operation per simulation.
// Reference calculations and result comparisons will be added next.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

// declare separate analysis input types
`uvm_analysis_imp_decl(_ctrl)
`uvm_analysis_imp_decl(_ram)
`uvm_analysis_imp_decl(_scratch)

class transform_scoreboard extends uvm_scoreboard;

    // receive configuration from the control monitor
    uvm_analysis_imp_ctrl #(transform_ctrl_transaction,transform_scoreboard) ctrl_imp;

    // receive completed reads from the RAM monitor
    uvm_analysis_imp_ram #(transform_ram_transaction,transform_scoreboard) ram_imp;

    // receive writes from the scratchpad monitor
    uvm_analysis_imp_scratch #(transform_scratch_transaction,transform_scoreboard) scratch_imp;

    // store the configuration of one operation
    transform_ctrl_transaction cfg;
    bit cfg_valid = 1'b0;

    // store observed reads and writes
    transform_ram_transaction ram_queue[$];
    transform_scratch_transaction scratch_queue[$];

    `uvm_component_utils(transform_scoreboard)

    function new(string name="transform_scoreboard", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        ctrl_imp = new("ctrl_imp",this);
        ram_imp = new("ram_imp",this);
        scratch_imp = new("scratch_imp",this);
    endfunction

    // receive one operation's configuration
    virtual function void write_ctrl(transform_ctrl_transaction tr);
        if(cfg_valid)begin
            `uvm_error("MULTIPLE_OPS","This scoreboard supports one operation per simulation")
            return;
        end

    cfg=transform_ctrl_transaction::type_id::create("cfg");
    cfg.copy(tr);
    cfg_valid=1'b1;

    `uvm_info("CTRL_RECEIVED",$sformatf("Configuration received: mode=%0d length=%0d", cfg.mode, cfg.length),UVM_LOW)
    endfunction

    // save one completed RAM read
    virtual function void write_ram(transform_ram_transaction tr);

        transform_ram_transaction saved_tr;
        saved_tr=transform_ram_transaction::type_id::create("saved_ram_tr");

        saved_tr.copy(tr);
        ram_queue.push_back(saved_tr);
    endfunction

    // saved one scratchpad write
    virtual function void write_scratch(transform_scratch_transaction tr);
        transform_scratch_transaction saved_tr;
        saved_tr=transform_scratch_transaction::type_id::create("saved_scratch_tr");

        saved_tr.copy(tr);
        scratch_queue.push_back(saved_tr);
    endfunction

    // calculate one expected Mode C output byte
    function automatic logic [7:0] predict_mode_c_byte(
        input logic [31:0] raw_data,
        input bit [hydra_pkg::DATA_BITS-1:0] scale_shift,
        input bit signed_out,
        input bit round_en
    );

        longint signed value;
        longint signed half_step;

        // preserve unknown input data
        if($isunknown(raw_data))begin
            return 8'hxx;
        end

        // interpret the input as a signed 32-bit number
        // assignment signed-extends it into the 64-bit varible
        value = $signed(raw_data);

        // add half of the divisor before shifting
        if(round_en && scale_shift!=0) begin
            half_step=64'sd1<<(scale_shift-1);
            value=value+half_step;
        end

        // arithmetic right shift preserves the sign
        value = value >>> scale_shift;

        // clamp to the selected output range
        if(signed_out) begin
            if(value>127)
                value=127;
            else if (value<-128)
                value=-128;
        end
        else begin
            if(value>255)
                value=255;
            else if (value<0)
                value=0;
        end

        return value[7:0];
    endfunction

    virtual function void check_phase(uvm_phase phase);
        int unsigned expected_reads;
        int unsigned expected_writes;

        logic [hydra_pkg::ADDR_WIDTH-1:0] expected_address;
        logic [31:0] expected_word;
        logic [7:0] expected_byte;

        bit failed;

        super.check_phase(phase);
        failed=1'b0;

        // check configuration
        if(!cfg_valid||cfg==null)begin
            `uvm_error("NO_CONFIG","No Transform configuration was received")
            return;
        end

        // check mode c 
        if(cfg.mode!=hydra_pkg::MODE_C)begin
            `uvm_error("UNSUPPORTED_MODE","This scoreboard currently checks Mode C")
            return;
        end

        // normal mode c operations require a nonzero
        // input length that is a multiple of four
        if(cfg.length==0||cfg.length%4!=0)begin
                `uvm_error("INVALID_LENGTH",$sformatf("Expected a nonzero multiple of four, got length=%0d",cfg.length))
                return;
        end

        expected_reads=cfg.length; // 32-bit
        expected_writes=cfg.length/4; //8-bit

        // check transaction counts
        if(ram_queue.size()!=expected_reads)begin
            `uvm_error("RAM_COUNT",$sformatf("Expected %0d RAM reads, observed %0d", expected_reads, ram_queue.size()))
            failed=1'b1;
        end

        if(scratch_queue.size()!=expected_writes)begin
            `uvm_error("SCRATCH_COUNT",$sformatf("Expected %0d scratchpad writes, observed %0d", expected_writes,scratch_queue.size()))
            failed=1'b1;
        end

        // avoid accessing missing queue entries
        if(failed)
        return;

        // check RAM read addresses, responses, and data validity
        for(int i=0; i<expected_reads; i++)begin
            expected_address=cfg.src_addr+i*4;
            if(ram_queue[i].address!==expected_address)begin
                `uvm_error("RAM_ADDRESS",$sformatf("Read %0d:expected address=0x%08h, actual=0x%08h",i,expected_address,ram_queue[i].address))
                failed=1'b1;
            end

            if(ram_queue[i].response!==1'b0)begin
                `uvm_error("RAM_RESPONSE",$sformatf("Read %0d:non-OKAY or unknown response",i))
                failed=1'b1;
            end

            if($isunknown(ram_queue[i].read_data))begin
                `uvm_error("RAM_DATA_UNKNOWN",$sformatf("Read %0d: data contains X or Z",i))
                failed=1'b1;
            end
        end

        if(failed)
        return;

        // predict and check each packed output word
        for(int w=0; w<expected_writes; w++)begin // word
            expected_word='0;
            for(int b=0;b<4;b++)begin //byte
                expected_byte=predict_mode_c_byte(
                    ram_queue[w*4+b].read_data,
                    cfg.scale_shift,
                    cfg.signed_out,
                    cfg.round_en
                );
                expected_word[b*8+:8]=expected_byte;
            end
            expected_address=cfg.dst_addr+w*4;

            if(scratch_queue[w].address!==expected_address)begin
                `uvm_error("SCRATCH_ADDRESS",$sformatf("Wirte %0d:expected address=0x%08h, actual=0x%08h",w,expected_address,scratch_queue[w].address))
                failed=1'b1;
            end

            if(scratch_queue[w].write_data!==expected_word)begin
                `uvm_error("MODE_C_DATA",$sformatf("Write %0d:expected data=0x%08h,actual=0x%08h",w,expected_word,scratch_queue[w].write_data))
                failed=1'b1;
            end
        end

        if(!failed)begin
            `uvm_info("MODE_C_MATCH",$sformatf("Checked %0d RAM reads and %0d scratchpad writes:addresses and data matched",expected_reads, expected_writes),UVM_LOW)
        end
        
    endfunction

    // report reception counts only
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SB_COUNTS",$sformatf("Configuration received=%0b, RAM reads=%0d, scratchpad writes=%0d", cfg_valid,ram_queue.size(),scratch_queue.size()),UVM_LOW)
    endfunction

endclass 



