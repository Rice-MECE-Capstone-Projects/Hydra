class hydra_integration_coverage extends uvm_subscriber #(cpu_ahb_transaction);
    `uvm_component_utils(hydra_integration_coverage)

    logic [31:0] length_reg;
    bit length_written;

    covergroup cfg_cg with function sample(
        bit [1:0] mode_v,
        bit valid_v,
        int unsigned length_v,
        bit signed_v,
        bit round_v,
        bit shifted_v,
        int unsigned blocks_v
    );
        option.per_instance = 1;

        cp_mode: coverpoint mode_v{
            bins mode_b={2};
            bins mode_c={3};
        }

        cp_valid: coverpoint valid_v {
            bins invalid={0};
            bins valid={1};
        }

        mode_x_valid: cross cp_mode, cp_valid;

        cp_b_blocks: coverpoint blocks_v
            iff (mode_v==2&&valid_v){
                bins one_block={1};
                bins two_blocks={2};
            }

        cp_c_length: coverpoint length_v
            iff (mode_v==3&&valid_v){
                bins four_inputs={4};
                bins more_inputs={[8:16]};
            }
        
        cp_c_signed: coverpoint signed_v
            iff (mode_v==3&&valid_v);
        
        cp_c_round: coverpoint round_v
            iff (mode_v==3&&valid_v);
        
        cp_c_shift: coverpoint shifted_v
            iff (mode_v==3&&valid_v);

        c_arithmetic: cross cp_c_signed, cp_c_round, cp_c_shift;
    endgroup

    function new(string name="hydra_integration_coverage",uvm_component parent=null);
        super.new(name,parent);
        cfg_cg=new();
    endfunction

    virtual function void write(cpu_ahb_transaction t);
        bit [1:0] mode_v;
        bit valid_v;
        int unsigned blocks_v;

        if(t.direction!=AHB_WRITE||t.response!==1'b0)
            return;
        
        if(t.address==32'h2000_000C)begin
            length_reg=t.write_data;
            length_written=1;
            return;
        end

        // Sample an operation when CPU writes CTRL with START=1
        if(t.address !=32'h2000_0000 || t.write_data[0]!=1'b1)
            return;

        if(!length_written)begin
            `uvm_error("COV_NO_LENGTH","START observed before LEN was written")
            return;
        end

        mode_v=t.write_data[2:1];

        case(mode_v)
            2: valid_v=(length_reg!=0&&length_reg%128==0);
            3: valid_v=(length_reg!=0&&length_reg%4==0);
            default: return;
        endcase

        blocks_v=(mode_v==2)?length_reg/128:0;

        cfg_cg.sample(
            mode_v,
            valid_v,
            length_reg,
            t.write_data[8],
            t.write_data[9],
            t.write_data[7:3]!=0,
            blocks_v
        );

        `uvm_info("COV_SAMPLE",$sformatf("mode=%0d length=%0d valid=%0b signed=%0b round=%0b shift_nonzero=%0b",mode_v,length_reg,valid_v,t.write_data[8],t.write_data[9],t.write_data[7:3]!=0),UVM_LOW)
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV_REPORT",$sformatf("Configuration coverage: %0.2f%%",cfg_cg.get_inst_coverage()),UVM_LOW)
    endfunction
endclass



            