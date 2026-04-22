## Architectural decisions:
1. **Scratchpad access:** Dual-port SRAM. CPU reads via AHB, HYDRA writes via private sideband port.
2. **AHB burst length:** INCR16. One burst per row of the 8x16 block. Arbiter preempts at burst boundaries only — HYDRA completes the current 16-beat burst before yielding grant.
3. **Error handling:** Abort immediately on HRESP = ERROR. FSM transitions to an ERROR halt state, STATUS.ERROR set in MMR. Transfer must be restarted by the CPU.
4. **Transposition flow:** Fill phase writes row-major into the ping-pong buffer (beat counter = buffer column index). Drain phase transposes on the way out to scratchpad — column-walk through the buffer, writing sequentially to the private sideband port.

## Scratchpad dual-port interface
### Sideband port signals:
```SystemVerilog
    output logic                            HYDRA_WE,
    output logic [SCRATCH_ADDR_WIDTH-1:0]   HYDRA_WADDR,
    output logic [31:0]                     HYDRA_WDATA
```
### 

### Parameters defined in `config/rv32gc/config.vh`
```SystemVerilog
// HYDRA DMA engine
localparam logic HYDRA_SUPPORTED             = 1;
localparam logic [63:0] HYDRA_MMR_BASE       = 64'h2000_0000;
localparam logic [63:0] HYDRA_MMR_RANGE      = 64'h0000_0FFF;
localparam logic [63:0] HYDRA_SCRATCH_BASE   = 64'h2001_0000;
localparam logic [63:0] HYDRA_SCRATCH_RANGE  = 64'h003F_FFFF;
localparam HYDRA_PLIC_ID                     = 32'd11;
```