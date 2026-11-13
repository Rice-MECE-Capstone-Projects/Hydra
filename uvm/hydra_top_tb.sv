`timescale 1ns/1ps

module hydra_top_tb;
    import uvm_pkg::*;
    import hydra_pkg::*;
    import hydra_uvm_pkg::*;
    import transform_pkg::*;
    import hydra_integration_pkg::*;

    logic clk=1'b0;
    logic hydra_grant;
    logic irq_hydra;
    logic cpu_bus_request=1'b0; 

    assign ahb_if.irq_hydra=irq_hydra;

    always #5 clk=~clk;

    cpu_ahb_if ahb_if(
        .clk(clk)
    );

    transform_ram_if ram_if(
        .clk(clk),
        .rst_n(ahb_if.rst_n),
        .hydra_grant(hydra_grant)
    );

    // Allow virtual interfaces in the imported Transform unit-test package to resolve.
    transform_ctrl_if unused_ctrl_if(
        .clk(clk),
        .rst_n(ahb_if.rst_n)
    );

    transform_scratch_if unused_scratch_if(
        .clk(clk),
        .rst_n(ahb_if.rst_n)
    );

    initial begin
        ahb_if.apply_reset();
    end

    hydra_top dut(
        .clk(clk),
        .rst_n(ahb_if.rst_n),

        // CPU accesses MMR and scratchpad through this slave port
        .hydra_HSEL (ahb_if.HSEL),
        .HADDR_s (ahb_if.HADDR),
        .HWDATA_s (ahb_if.HWDATA),
        .HWRITE_s (ahb_if.HWRITE),
        .HTRANS_s (ahb_if.HTRANS),
        .HREADY_s (ahb_if.HREADY),
        .HRDATA_s (ahb_if.HRDATA),
        .HREADYOUT_s (ahb_if.HREADYOUT),
        .HRESP_s (ahb_if.HRESP),

        // Transform reads input data through this master port
        .HADDR_m (ram_if.HADDR),
        .HBURST_m (ram_if.HBURST),
        .HSIZE_m (ram_if.HSIZE),
        .HTRANS_m (ram_if.HTRANS),
        .HWDATA_m (ram_if.HWDATA),
        .HWSTRB_m (),
        .HWRITE_m (ram_if.HWRITE),
        .HPROT_m (),
        .HMASTLOCK_m (),
        .HRDATA_m (ram_if.HRDATA),
        .HREADY_m (ram_if.HREADY),
        .HRESP_m (ram_if.HRESP),

        .HTRANS1_cpu (cpu_bus_request),
        .hydra_grant (hydra_grant),
        .irq_hydra (irq_hydra)
    );

    assign unused_scratch_if.SCRATCH_WE=dut.SCRATCH_WE;
    assign unused_scratch_if.SCRATCH_WADDR=dut.SCRATCH_WADDR;
    assign unused_scratch_if.SCRATCH_WDATA=dut.SCRATCH_WDATA;
    
    initial begin
        uvm_config_db#(virtual cpu_ahb_if)::set(null,"*","vif",ahb_if);
        uvm_config_db#(virtual transform_ram_if)::set(null,"*","vif",ram_if);
        uvm_config_db#(virtual transform_scratch_if)::set(null,"*","vif",unused_scratch_if);
        run_test();
    end

    initial begin : cpu_contention_stimulus
        if($test$plusargs("CPU_CONTENTION"))begin
            wait(hydra_grant===1'b1);
            repeat(4) @(negedge clk);
            cpu_bus_request=1'b1;

            // HYDRA finishes the current burst before yielding the bus
            for(int i=0;(i<32)&&(hydra_grant!==1'b0);i++)
                @(negedge clk);
            if(hydra_grant!==1'b0)
                $fatal(1,"HYDRA didn't yield the bus");

            repeat (4) @(negedge clk);
            cpu_bus_request=1'b0;

            for(int i=0;(i<10)&&(hydra_grant!==1'b1);i++)
                @(negedge clk);
            if(hydra_grant!==1'b1)
                $fatal(1,"HYDRA did not regain the bus");
            
            $display("[ARB_CHECK] HYDRA yielded and regained the bus");
        end
    end

endmodule

        

