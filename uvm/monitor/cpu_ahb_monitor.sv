class cpu_ahb_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_ahb_monitor)

    virtual cpu_ahb_if vif;

    uvm_analysis_port #(cpu_ahb_transaction) ap;

    function new(string name = "cpu_ahb_monitor", uvm_component parent=null);
        super.new(name,parent);
        ap = new ("ap",this);
    endfunction

    //build phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db #(virtual cpu_ahb_if)::get(this,"","vif",vif))begin
            `uvm_fatal(get_type_name(),"Didn't get handle to virtual interface")
        end
    endfunction
    
    //run phase
    virtual task run_phase(uvm_phase phase);
        cpu_ahb_transaction tr;

        forever begin
            @(vif.monitor_cb);

            if(vif.monitor_cb.rst_n===1'b1 &&
               vif.monitor_cb.HSEL===1'b1 && //hit mmr
               vif.monitor_cb.HTRANS[1] === 1'b1 && // request type
               vif.monitor_cb.HREADY === 1'b1) begin

                tr = cpu_ahb_transaction::type_id::create("tr");

                tr.address = vif.monitor_cb.HADDR;

                if(vif.monitor_cb.HWRITE == 1'b1)
                    tr.direction = AHB_WRITE;
                else 
                    tr.direction = AHB_READ;

                //wait data/response phase
                do begin
                    @(vif.monitor_cb);
                end while (
                    vif.monitor_cb.HREADYOUT != 1'b1 //finish reading
                );

                if (tr.direction == AHB_WRITE) begin
                    tr.write_data = vif.monitor_cb.HWDATA;
                    tr.read_data = '0;
                end
                else begin
                    tr.write_data = '0;
                    tr.read_data = vif.monitor_cb.HRDATA;
                end

                tr.response = vif.monitor_cb.HRESP;

                //boardcast to scoreboard/coverage
                ap.write(tr);
               end
        end
    endtask


endclass