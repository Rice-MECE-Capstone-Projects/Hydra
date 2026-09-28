class cpu_ahb_scoreboard extends uvm_scoreboard;

`uvm_component_utils(cpu_ahb_scoreboard)

// receive transaction from the monitor
uvm_analysis_imp #(
    cpu_ahb_transaction, cpu_ahb_scoreboard
)cpu_ahb_imp;

// expected SRC value
//logic [31:0] expected_src;
//bit src_valid =1'b0;

// Index 0:SRC, 1:DST, 2:LEN
logic [31:0] expected_value[3];
bit valid[3] ='{default:1'b0};

function new (string name="cpu_ahb_scoreboard",uvm_component parent=null);
    super.new(name,parent);
endfunction

// build_phase
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_ahb_imp=new("cpu_ahb_imp",this);
endfunction

// reset
function void reset_model();
    foreach (expected_value[i]) begin
        expected_value[i]='0;
        valid[i]=1'b1;
    end
endfunction

// called when the monitor publishes a transaction
virtual function void write(cpu_ahb_transaction tr);

    int index;
    string reg_name;
    
    // check the bus response for every transaction
    if(tr.response !==1'b0)begin
        `uvm_error("AHB_RESPONSE",$sformatf("Non-OKAY or unknown response at address 0x%08h",tr.address))
    return;
    end

/* check the SRC register
if(tr.address === 32'h0000_0004)begin
    if(tr.direction==AHB_WRITE) begin
        expected_src = tr.write_data;
        src_valid=1'b1;
    end
    else if (tr.direction==AHB_READ)begin
        if(!src_valid)begin
            `uvm_warning("SRC_NO_EXPECTED","SRC read before an observed write; comparison skipped")
        end
        else if (tr.read_data!==expected_src)begin
            `uvm_error("SRC MISMATCH",$sfomatf("Expected SRC=0x%8h,actual=0x08h",expected_src,tr.read_data))
        end
        else begin
            `uvm_info("SRC_MATCH",$sformatf("SRC readback passed: 0x%08h",tr.read_data),UVM_LOW)
        end
    end
end
*/

//identify the register
case(tr.address)
    32'h0000_0004:begin
        index=0;
        reg_name="SRC";
    end

    32'h0000_0008:begin
        index=1;
        reg_name="DST";
    end

    32'h0000_000C:begin
        index=2;
        reg_name="LEN";
    end

    default:return;
endcase

if(tr.direction==AHB_WRITE)begin
    expected_value[index]=tr.write_data;

    if(index==2)begin
        expected_value[index]='0;
        expected_value[index][hydra_pkg::LEN_WIDTH-1:0] = tr.write_data[hydra_pkg::LEN_WIDTH-1:0];
    end
    valid[index]=1'b1;

end
else if (tr.direction==AHB_READ)begin
    if(!valid[index])begin
        `uvm_error("NO_EXPECTED",$sformatf("%s read without an observed write", reg_name))
    end
    else if (tr.read_data !== expected_value[index])begin
        `uvm_error("REG_MISMATCH",$sformatf("%s expected=0x%08h,actual=0x%08h",reg_name,expected_value[index],tr.read_data))
    end
    else begin
        `uvm_info("REG_MATCH", $sformatf("%s readback passed:0x%08h",reg_name,tr.read_data),UVM_LOW)
    end
end

endfunction
endclass





