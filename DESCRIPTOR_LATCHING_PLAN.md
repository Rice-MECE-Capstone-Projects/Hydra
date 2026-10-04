# MMR Busy-Write Protection Plan

## Goal

Prevent software from changing the descriptor while HYDRA is using it by
blocking MMR writes for the duration of an active job. The transform continues
to consume the MMR outputs directly; no duplicate active-descriptor registers
are added.

## Register behavior

- `STATUS[0]` remains the sticky `ERROR` bit.
- `STATUS[1]` reports `BUSY`.
- While busy, writes to every MMR register are ignored, including writes to
  `CTRL.START` and `STATUS` error-clear.
- Busy writes are discarded, not deferred. Software must wait for busy to
  clear, then reissue any desired programming writes and start request.
- Reads remain available while busy so software can poll status.

## Implementation steps

### 1. Generate and route busy

In `src/hydra/hydra_transform.sv`, add a `busy` output that is asserted in
`BUSY` or `FLUSH`, or while a start pulse is pending. Including the start pulse
closes the cycle between MMR generating `start` and the FSM entering `BUSY`,
preventing a back-to-back write from changing fields at launch. The error state
is not busy, so software can inspect/clear the error and reprogram a failed job.

Wire this output through `src/hydra/hydra_top.sv` to a new `busy` input on
`src/hydra/hydra_mmr.sv`.

### 2. Gate MMR writes and report status

In `hydra_mmr.sv`, update register writes only when the write data phase is
valid and `busy` is low. Do not stall the AHB transfer; a rejected write
completes normally and is discarded.

Return `busy` in `STATUS[1]` while preserving the existing sticky error
behavior in `STATUS[0]`. Keep MMR reads enabled while busy.

### 3. Keep the transform on live MMR outputs

Do not add descriptor snapshot registers. As the MMR refuses writes from job
launch through completion/error, the transform's live mode, addresses, length,
and operation parameters remain stable for the whole job.

The controller should enter `BUSY` only in response to `start`, and validate
the descriptor at that boundary. An idle transform with no start must not
report an error or request the bus merely because the programmed length is
invalid or uninitialized. Keep `done` aligned with the return to idle so
software can start another job as soon as completion is reported.

### 4. Document software sequencing

Update the project documentation and MMR register-map comments to describe
`STATUS[1]`, the ignored-write policy, and the requirement to wait for busy to
clear before programming the next descriptor. Busy-time writes are never
queued.

### 5. Verify write protection and regression behavior

Extend the Questa testbench to verify:

- Descriptor writes are accepted while idle.
- `STATUS[1]` tracks busy, while `STATUS[0]` retains its sticky error meaning.
- Writes to descriptor, control/start, and status-clear registers are ignored
  while busy.
- Those writes are accepted again once busy clears.
- The transform busy output asserts from start acceptance through successful
  completion, then clears. After an error, it clears so software may reprogram
  and retry while the MMR's sticky error bit remains set.
- Existing transform mode, wait-state, error, and output-data tests still pass.

## Completion criteria

- The transform has no active-descriptor shadow registers.
- MMR writes cannot alter any descriptor field while busy.
- Software can observe busy through `STATUS[1]`.
- Busy-time writes complete as normal AHB accesses but have no register effect.
- Existing status error behavior and transform functionality are preserved.
