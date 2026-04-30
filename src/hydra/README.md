## Architectural decisions:
1. **Scratchpad access:** Dual-port SRAM. CPU reads via AHB, HYDRA writes via private sideband port.
2. **AHB burst length:** INCR16. One burst per row of the 8x16 block. Arbiter preempts at burst boundaries only — HYDRA completes the current 16-beat burst before yielding grant.
3. **Error handling:** Abort immediately on HRESP = ERROR. FSM transitions to an ERROR halt state, STATUS.ERROR set in MMR. Transfer must be restarted by the CPU.
4. **Transposition flow:** Fill phase writes row-major into the ping-pong buffer (beat counter = buffer column index). Drain phase transposes on the way out to scratchpad — column-walk through the buffer, writing sequentially to the private sideband port.

---

## Scratchpad dual-port interface
### Sideband port signals:
```SystemVerilog
    output logic                            HYDRA_WE,
    output logic [SCRATCH_ADDR_WIDTH-1:0]   HYDRA_WADDR,
    output logic [31:0]                     HYDRA_WDATA
```

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

---

## Setup

Simulation requires **QuestaSim** (ModelSim-compatible) to be installed and available on your `PATH` — make sure `vlib`, `vlog`, and `vsim` can be called from your terminal before proceeding.

If this is your first time running the project, create the QuestaSim working library before anything else:

```bash
vlib work
```

This only needs to be done once per environment. Two executable scripts are provided at the root of `src/hydra/`:

- **`run`** — headless simulation. Compiles all source files and runs the testbench without opening any GUI, then exits. All `$display` output is captured in `hydra_tb.log` and waveform data is dumped to `hydra_tb.vcd`. This is the quickest way to iterate: edit a source file, run `./run`, and check the log.

- **`runwave`** — GUI simulation. Compiles and opens QuestaSim's graphical interface with all signals already added to the Wave window and the simulation run in full. `$display` output appears in QuestaSim's Transcript panel and waveforms are interactive in the Wave panel. Use this when you need more in-depth visual inspection inside QuestaSim — it gives you access to memory cell contents and additional debugging tools such as FSM state visualization.

If you are using `run` and want to inspect the generated `.vcd` waveform file without leaving your editor, the [**Surfer**](https://marketplace.visualstudio.com/items?itemName=surfer-project.surfer) extension for VSCode renders `.vcd` files as interactive waveforms directly in the editor — just open `hydra_tb.vcd` after a run. If you are not using VSCode, [**GTKWave**](https://gtkwave.sourceforge.net/) is a free, platform-independent alternative that opens `.vcd` files directly.