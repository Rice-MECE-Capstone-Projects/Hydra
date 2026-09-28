class mmr_pattern_sequence extends uvm_sequence #(cpu_ahb_transaction);
    `uvm_object_utils(mmr_pattern_sequence)

    function new(string name="mmr_pattern_sequence");
        super.new(name);
    endfunction

    virtual task body();
        cpu_ahb_transaction tr;

        logic [31:0] addresses[3]='{
            32'h0000_0004,
            32'h0000_0008,
            32'h0000_000C
        };

        logic [31:0] patterns[36];
        logic [31:0] expected;

        // four fixed patterns
        patterns[0] = 32'h0000_0000;
        patterns[1] = 32'hFFFF_FFFF;
        patterns[2] = 32'hAAAA_AAAA;
        patterns[3] = 32'h5555_5555;

        // walking-one patterns
        for(int bit_index = 0; bit_index < 32; bit_index++)begin
            patterns[bit_index+4]=32'h0000_0001<<bit_index;
        end

        // test every pattern on every register
        for(int p=0;p<36;p++)begin
            for(int r=0;r<3;r++)begin

                //write
                tr=cpu_ahb_transaction::type_id::create($sformatf("write_p%0d_r%0d",p,r));

                start_item(tr);

                tr.direction=AHB_WRITE;
                tr.address=addresses[r];
                tr.write_data=patterns[p];

                finish_item(tr);

                if(tr.response!==1'b0)begin
                    `uvm_error("PATTERN_WRITE",$sformatf("Write failed:address=0x%08h pattern=0x%08h",addresses[r],patterns[p]))
                end

                // calculate the expected readback
                expected=patterns[p];

                if(r==2)begin
                    expected='0;
                    expected[hydra_pkg::LEN_WIDTH-1:0]=patterns[p][hydra_pkg::LEN_WIDTH-1:0];
                end

                // read
                tr=cpu_ahb_transaction::type_id::create($sformatf("read_p%0d_r%0d",p,r));
                
                start_item(tr);
                tr.direction=AHB_READ;
                tr.address=addresses[r];
                finish_item(tr);

                // check the driver's readback against theh requested value
                if (tr.response!==1'b0)begin
                    `uvm_error("PATTERN_READ","READ response failed")
                end
                else if (tr.read_data !== expected)begin
                    `uvm_error("PATTERN_MISMATCH",$sformatf(
                        "Address=0x%08h writtern=0x%08h expected=0x%08h actual=0x%08h",
                        addresses[r],patterns[p],expected,tr.read_data
                    ))
                end
            end
        end

        `uvm_info("PATTERN_DONE","Completed 108 register write/read pairs",UVM_LOW)
                

    endtask
endclass