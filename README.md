# HYDRA
**High-Yield Data Reorganization and Acceleration**

HYDRA is a smart DMA engine integrated into the
[CORE-V Wally](https://github.com/openhwgroup/cvw) RISC-V SoC as a second
AHB master. It offloads data-reorganization operations from the CPU into
dedicated hardware datapaths, targeting AI/ML and DSP workloads where data
movement cost dominates compute cost.

HYDRA implements three operation modes:

- **Mode A — Scatter-gather:** collects non-contiguous vectors from main RAM
  and packs them into a contiguous scratchpad buffer.
- **Mode B — Matrix transposition:** corner-turning over 8×16 blocks of INT32
  words using a ping-pong SRAM architecture, targeting Q/K/V layout swaps in
  Transformer inference.
- **Mode C — In-flight quantization:** combinational INT32→INT8 precision
  reduction with 4:1 word packing, delivering 4× effective bandwidth on the
  write side.

HYDRA is integrated into Wally's uncore as an AHB slave (MMR at
`0x2000_0000`) and AHB master (data-plane transfers from main RAM at
`0x8000_0000` to scratchpad at `0x2001_0000`). Completion is signaled via
a PLIC interrupt (source 11).

This is a Rice University capstone project. The design targets functional
correctness and measured speedup (≥ 10× on matrix transposition vs.
software baseline). It is implementation-technology agnostic: it synthesizes
with standard-cell DFFs when no SRAM macro is available, and can be
retargeted to any PDK by substituting the scratchpad primitive.

---

## Repository structure

```
hydra/
├── wally/          Wally cvw submodule (pinned — do not commit inside here)
├── src/hydra/      HYDRA RTL source files
├── patch/          Patches applied to Wally source files
├── scripts/
│   └── wally       Submodule management (update + save)
├── sim/            Testbenches and cocotb tests
├── synth/          Synthesis scripts and reports
├── cache/          Cache (folder from old projects)
├── core/           Core (folder from old projects)
├── DFT/            Design-for-test (Yue)
├── verif/          Verification (folder from old projects)
└── pdfs/           Project reports
```

---

## Setup

### First time (after cloning)

```bash
git clone https://github.com/Rice-MECE-Capstone-Projects/Hydra.git
cd Hydra
./scripts/wally update
```

### After pulling

```bash
git pull
./scripts/wally update
```

Always run `./scripts/wally update` after pulling. It syncs the Wally
submodule to its pinned commit and reapplies all HYDRA patches. If you skip
this step, the Wally files in your working tree will not have the HYDRA
additions and simulation/synthesis will fail.

---

## How the Wally patches work

HYDRA modifies a small number of Wally source files (config, uncore, top-level
SoC). Rather than copying or forking Wally, these modifications are stored as
`.patch` files in `patch/`. `./scripts/wally update` applies them to the Wally
submodule working tree after every sync.

Wally's git history is never touched. The submodule pointer in this repo pins
Wally to a specific commit, and patches are generated against that exact base.

### Adding or updating a patch

1. Edit the target file inside `wally/`:
```bash
nano wally/config/rv32gc/config.vh
```

2. Save the patch:
```bash
./scripts/wally save
```

3. Stage and commit the updated `patch/` files.

Never stage or commit anything inside `wally/`. The submodule tracks only the
pinned commit pointer, not the working tree contents.

### Files currently patched

| Patch file | Wally file modified | Purpose |
|---|---|---|
| `config_rv32gc.patch` | `config/rv32gc/config.vh` | HYDRA base addresses, PLIC source ID |
| `wallypipelinedsoc.patch` | `src/wally/wallypipelinedsoc.sv` | Instantiate `hydra_top` |
| `uncore.patch` | `src/uncore/uncore.sv` | Address decode, scratchpad, interrupt |
| `adrdecs.patch` | `src/uncore/adrdecs.sv` | PMA entries for MMR and scratchpad |

---

## HYDRA RTL modules

| Module | File | Description |
|---|---|---|
| `hydra_top` | `src/hydra/hydra_top.sv` | Top-level wrapper. AHB master + slave ports, scratchpad sideband |
| `hydra_mmr` | `src/hydra/hydra_mmr.sv` | AHB-Lite slave MMR. Holds CTRL, SRC, DST, LEN, STATUS. Zero wait-state |
| `hydra_transform` | `src/hydra/hydra_transform.sv` | AHB master FSM, AGU, ping-pong buffers (Mode B), quant pipeline (Mode C) |
| `hydra_arbiter` | `src/hydra/hydra_arbiter.sv` | Static-priority Moore FSM. CPU priority, burst-boundary preemption |

---

## Memory map

| Region | Base | Size | Attributes |
|---|---|---|---|
| Boot ROM | `0x0000_1000` | 4 KB | Read-only |
| CLINT | `0x0200_0000` | 64 KB | MMIO |
| PLIC | `0x0C00_0000` | 64 MB | MMIO |
| UART / GPIO | `0x1000_0000` | — | MMIO |
| HYDRA MMR | `0x2000_0000` | 4 KB | Non-cacheable |
| Scratchpad | `0x2001_0000` | 4 MB | Non-cacheable |
| Main RAM | `0x8000_0000` | 128 MB | Cached (I$/D$) |

---

## License

HYDRA RTL (`src/hydra/`) — Apache-2.0 WITH SHL-2.1  
Wally submodule (`wally/`) — Apache-2.0 WITH SHL-2.1 (OpenHW Group)  
Patches (`patch/`) — Apache-2.0 WITH SHL-2.1