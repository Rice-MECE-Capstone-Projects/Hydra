# RISC-V Data Cache UVM Verification

## Overview
This project implements a SystemVerilog UVM-based verification environment for a direct-mapped RISC-V data cache. The goal is to validate cache functionality under both hit and miss scenarios using constrained-random stimulus and transaction-level checking.

The verification environment follows a standard UVM architecture, including sequence generation, driver-based stimulus application, monitor-based transaction reconstruction, and scoreboard-based functional checking.


## Verification Architecture

The environment is composed of the following components:

- **Sequence Item (`cpu_sequence_item`)**  
  Defines the transaction format, including request fields (address, write enable, write data, byte enable) and response field (read data).

- **Sequence (`cpu_sequence`)**  
  Generates constrained-random transactions with a biased distribution:
  - 70% address reuse → likely cache hit
  - 30% random address → likely cache miss

- **Driver (`cpu_driver`)**  
  Converts transactions into pin-level stimulus and drives them to the DUT interface. Implements a two-phase handshake protocol:
  - Request phase: `data_req + data_gnt`
  - Completion phase: `data_rvalid` (read) or `stall release` (write)

- **Monitor (`cpu_monitor`)**  
  Observes DUT signals and reconstructs transactions:
  - Tracks outstanding requests using queues
  - Matches responses based on protocol timing
  - Sends completed transactions to the scoreboard

- **Agent (`cpu_agent`)**  
  Encapsulates driver, sequencer, and monitor. Configurable as active or passive.

- **Environment (`cpu_env`)**  
  Instantiates agent and scoreboard, and connects monitor output to the checking logic.

- **Test (`cpu_test`)**  
  Starts the sequence and manages simulation flow using UVM objection mechanism.

## Functional Coverage Strategy

The stimulus is designed to exercise both hit and miss behaviors:

- Temporal locality (address reuse) → hit scenarios
- Random address generation → miss scenarios
- Random read/write operations
- Full byte enable accesses


## Simulation Flow

### Compile
Compile all UVM components and DUT:
```bash
vlog *.sv
