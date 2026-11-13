//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_scoreboard.sv
//
// Author: Yulia Zhou
//
// Description:
// Collects control configurations, completed RAM reads, and scratchpad writes.
// Checks Mode C quantization and packing, and Mode B matrix transposition.
// Uses the shared preloaded RAM model to check Mode B input and output data.
//
// Scope:
// Supports multiple valid Mode B or Mode C operations per simulation.
// Checks transaction counts, addresses, RAM responses, and output data.
// Invalid-length no-traffic checking currently covers Mode C only.
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
    transform_ctrl_transaction cfg_queue[$];
    bit expect_invalid_length =1'b0;

    // store observed reads and writes
    transform_ram_transaction ram_queue[$];
    transform_scratch_transaction scratch_queue[$];

    transform_ram_model ram_model;

    `uvm_component_utils(transform_scoreboard)

    function new(string name="transform_scoreboard", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(transform_ram_model)::get(this,"","ram_model",ram_model))
            `uvm_fatal("NO_RAM_MODEL","Scoreboard can't access the shared RAM model")

        ctrl_imp = new("ctrl_imp",this);
        ram_imp = new("ram_imp",this);
        scratch_imp = new("scratch_imp",this);

    endfunction

    // receive one operation's configuration
    virtual function void write_ctrl(transform_ctrl_transaction tr);
        transform_ctrl_transaction saved_cfg;

        saved_cfg=transform_ctrl_transaction::type_id::create("saved_cfg");
        saved_cfg.copy(tr);
        cfg_queue.push_back(saved_cfg);

        `uvm_info("CTRL_RECEIVED",$sformatf("Operation %0d: mode=%0d length=%0d src=0x%08h dst=0x%08h",
                    cfg_queue.size(),saved_cfg.mode,saved_cfg.length, saved_cfg.src_addr,saved_cfg.dst_addr),UVM_LOW)
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
        int unsigned total_reads;
        int unsigned total_writes;
        int unsigned read_base;
        int unsigned write_base;
        int unsigned expected_reads;
        int unsigned expected_writes;
        int unsigned block_idx, elem_idx, row_idx, col_idx;

        logic [hydra_pkg::ADDR_WIDTH-1:0] expected_address;
        logic [31:0] expected_word;
        logic [7:0] expected_byte;

        bit failed;

        super.check_phase(phase);
        total_reads=0;
        total_writes=0;
        read_base=0;
        write_base=0;
        failed=1'b0;

        if(cfg_queue.size()==0)begin
            `uvm_error("NO_CONFIG","No Transform configuration was received")
            return;
        end

        if(expect_invalid_length)begin
            if(cfg_queue.size()!=1)begin
                `uvm_error("EXPECTED_INVALID_LENGTH","Expected exactly one invalid configuration")
            end
            else begin
                case(cfg_queue[0].mode)
                    hydra_pkg::MODE_C:begin
                        if(cfg_queue[0].length!=0 && cfg_queue[0].length%4==0)
                            `uvm_error("EXPECTED_INVALID_LENGTH","Expected an invalid Mode C length")
                    end

                    hydra_pkg::MODE_B:begin
                        if(cfg_queue[0].length!=0 && cfg_queue[0].length%(hydra_pkg::BLOCK_ROWS*hydra_pkg::BLOCK_COLS)==0)
                            `uvm_error("EXPECTED_INVALID_LENGTH","Expected an invalid Mode B length")
                    end

                    default:
                        `uvm_error("EXPECTED_INVALID_LENGTH","Unexpected mode")
                endcase
            end

            if(ram_queue.size()!=0||scratch_queue.size()!=0)begin
                `uvm_error("INVALID_LENGTH_TRAFFIC",$sformatf("Expected 0 reads and 0 writes; observed %0d reads and %0d writes", ram_queue.size(),scratch_queue.size()))
            end else begin
                `uvm_info("INVALID_LENGTH_NO_TRAFFIC","No RAM reads or scratchpad writes were observed", UVM_LOW)
            end
            return;
        end

        // first calculate totals, so no queue entry is accessed if traffic is missing
        foreach (cfg_queue[op]) begin
            case (cfg_queue[op].mode)
                hydra_pkg::MODE_C:begin
                    if(cfg_queue[op].length==0||cfg_queue[op].length%4!=0)begin
                        `uvm_error("INVALID_LENGTH",$sformatf("Operation %0d has invalid Mode C length=%0d",op,cfg_queue[op].length))
                    return;
                    end
                    total_reads += cfg_queue[op].length;
                    total_writes += cfg_queue[op].length/4;
                end

                hydra_pkg::MODE_B:begin
                    if(cfg_queue[op].length==0||cfg_queue[op].length%
                        (hydra_pkg::BLOCK_ROWS*hydra_pkg::BLOCK_COLS)!=0)begin
                            `uvm_error("INVALID_LENGTH", $sformatf("Operation %0d has invalid Mode B length=%0d",op,cfg_queue[op].length))
                            return;
                        end
                        total_reads += cfg_queue[op].length;
                        total_writes += cfg_queue[op].length;
                end

                default:begin
                    `uvm_error("UNSUPPORTED_MODE",$sformatf("Operation %0d has unsupported mode=%0d",op,cfg_queue[op].mode))
                    return;
                end
            endcase
        end

        // check transaction counts
        if(ram_queue.size()!=total_reads)begin
            `uvm_error("RAM_COUNT",$sformatf("Expected %0d RAM reads, observed %0d", total_reads, ram_queue.size()))
            failed=1'b1;
        end

        if(scratch_queue.size()!=total_writes)begin
            `uvm_error("SCRATCH_COUNT",$sformatf("Expected %0d scratchpad writes, observed %0d", total_writes,scratch_queue.size()))
            failed=1'b1;
        end

        // avoid accessing missing queue entries
        if(failed)
        return;

        foreach (cfg_queue[op]) begin
        expected_reads = cfg_queue[op].length;
        expected_writes = (cfg_queue[op].mode==hydra_pkg::MODE_C)?expected_reads/4:expected_reads;

        // check RAM read addresses, responses, and data validity
        for(int i=0; i<expected_reads; i++)begin
            expected_address=cfg_queue[op].src_addr+i*4;

            if(ram_queue[read_base+i].address!==expected_address)begin
                `uvm_error("RAM_ADDRESS",$sformatf("Operation %0d Read %0d:expected address=0x%08h, actual=0x%08h",op,i,expected_address,ram_queue[read_base+i].address))
                failed=1'b1;
            end

            if(ram_queue[read_base+i].response!==1'b0)begin
                `uvm_error("RAM_RESPONSE",$sformatf("Operation %0d Read %0d:non-OKAY response",op,i))
                failed=1'b1;
            end

            if($isunknown(ram_queue[read_base+i].read_data))begin
                `uvm_error("RAM_DATA_UNKNOWN",$sformatf("Operation %0d Read %0d contains X or Z",op,i))
                failed=1'b1;
            end

            if(cfg_queue[op].mode == hydra_pkg::MODE_B)begin
                expected_word=ram_model.read_word(expected_address);
                if(ram_queue[read_base+i].read_data!==expected_word)begin
                    `uvm_error("RAM_DATA",$sformatf("Operation %0d read %0d: expected data=0x%08h, actual=0x%08h",op,i,expected_word,ram_queue[read_base+i].read_data))
                    failed=1'b1;
                end
            end
        end

        // predict and check each packed output word
        if(cfg_queue[op].mode==hydra_pkg::MODE_C)begin
            for(int w=0; w<expected_writes; w++)begin // word
                expected_word='0;
                for(int b=0;b<4;b++)begin //byte
                    expected_byte=predict_mode_c_byte(
                        ram_queue[read_base+w*4+b].read_data,
                        cfg_queue[op].scale_shift,
                        cfg_queue[op].signed_out,
                        cfg_queue[op].round_en
                    );
                    expected_word[b*8+:8]=expected_byte;
                end
                expected_address=cfg_queue[op].dst_addr+w*4;

                if(scratch_queue[write_base+w].address!==expected_address)begin
                    `uvm_error("SCRATCH_ADDRESS",$sformatf("Operation %0d Wirte %0d:expected address=0x%08h, actual=0x%08h",op,w,expected_address,scratch_queue[write_base+w].address))
                    failed=1'b1;
                end

                if(scratch_queue[write_base+w].write_data!==expected_word)begin
                    `uvm_error("MODE_C_DATA",$sformatf("Operation %0d Write %0d:expected data=0x%08h,actual=0x%08h",op,w,expected_word,scratch_queue[write_base+w].write_data))
                    failed=1'b1;
                end
            end 
        end else begin //MODE B
                for(int w=0;w<expected_writes;w++)begin
                    block_idx=w/(hydra_pkg::BLOCK_ROWS*hydra_pkg::BLOCK_COLS);
                    elem_idx=w%(hydra_pkg::BLOCK_ROWS*hydra_pkg::BLOCK_COLS);
                    row_idx=elem_idx/hydra_pkg::BLOCK_COLS;
                    col_idx=elem_idx%hydra_pkg::BLOCK_COLS;

                    expected_address = cfg_queue[op].dst_addr 
                        + block_idx * hydra_pkg::BLOCK_ROWS * hydra_pkg::BLOCK_COLS * 4
                        + (col_idx * hydra_pkg::BLOCK_ROWS + row_idx) * 4;

                    expected_word = ram_model.read_word(cfg_queue[op].src_addr+w*4);

                    if(scratch_queue[write_base+w].address!==expected_address)begin
                        `uvm_error("MODE_B_ADDRESS",$sformatf("Operation %0d write %0d: expected address=0x%08h, actual=0x%08h",op,w,expected_address,scratch_queue[write_base+w].address))
                        failed=1'b1;
                    end

                    if(scratch_queue[write_base+w].write_data!==expected_word)begin
                        `uvm_error("MODE_B_DATA",$sformatf("Operation %0d write %0d: expected data=0x%08h, actual=0x%08h",op,w,expected_word,scratch_queue[write_base+w].write_data))
                        failed=1'b1;
                    end
                end
            end
            read_base+=expected_reads;
            write_base+=expected_writes;
        end

        if(!failed)begin
            `uvm_info("TRANSFORM_MATCH",$sformatf("Checked %0d operations, %0d RAM reads and %0d scratchpad writes",cfg_queue.size(),total_reads,total_writes),UVM_LOW)
        end
        
    endfunction

    // report reception counts only
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SB_COUNTS",$sformatf("Configuration received=%0d, RAM reads=%0d, scratchpad writes=%0d", cfg_queue.size(),ram_queue.size(),scratch_queue.size()),UVM_LOW)
    endfunction

endclass 



