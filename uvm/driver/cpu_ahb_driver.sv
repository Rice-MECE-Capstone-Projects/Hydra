// write: driver--HWDATA/HADDR-->MMR
// read: driver--HADDR-->MMR--HRDATA-->driver

class cpu_ahb_driver extends uvm_driver #(cpu_ahb_transaction);

    `uvm_component_utils (cpu_ahb_driver)

    //virtual if handle
    virtual cpu_ahb_if vif;

    function new(string name="cpu_ahb_driver", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    //build phase
    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
    if(!uvm_config_db #(virtual cpu_ahb_if)::get(this,"","vif",vif))begin
        `uvm_fatal(get_type_name(),"Didn't get handle to virtual interface")
    end
    endfunction

    //run phase
    virtual task run_phase(uvm_phase phase);
        cpu_ahb_transaction tr;

        //initial
        vif.driver_cb.HADDR<=32'b0;
        vif.driver_cb.HWDATA<=32'b0;
        vif.driver_cb.HWRITE<=1'b0;
        vif.driver_cb.HSEL<=1'b0;
        vif.driver_cb.HTRANS<=2'b00;
        vif.driver_cb.HREADY<=1'b1;

        wait(vif.rst_n===1'b1);

        forever begin
            seq_item_port.get_next_item(tr);

            @(vif.driver_cb);

            // request
            vif.driver_cb.HADDR<=tr.address;
            vif.driver_cb.HWRITE<=(tr.direction==AHB_WRITE);
            vif.driver_cb.HSEL<= 1'b1;
            vif.driver_cb.HTRANS<=2'b10;//NONSEQ
            vif.driver_cb.HREADY<=1'b1;

            if(tr.direction==AHB_WRITE)
                vif.driver_cb.HWDATA<=tr.write_data;
            else
                vif.driver_cb.HWDATA<=32'b0;

            @(vif.driver_cb);

            //IDLE
            vif.driver_cb.HADDR<=32'b0;
            vif.driver_cb.HWRITE<=1'b0;
            vif.driver_cb.HSEL<=1'b0;
            vif.driver_cb.HTRANS<=2'b00;
            vif.driver_cb.HREADY <= 1'b1;

            do begin
                @(vif.driver_cb);
            end while(vif.driver_cb.HREADYOUT!==1'b1);

            // response 
            if(tr.direction==AHB_READ)
                tr.read_data = vif.driver_cb.HRDATA;
            else
                tr.read_data = 32'b0;

            tr.response = vif.driver_cb.HRESP;//error=1 

            vif.driver_cb.HWDATA<=32'b0;

            seq_item_port.item_done();
        end
    endtask

endclass

