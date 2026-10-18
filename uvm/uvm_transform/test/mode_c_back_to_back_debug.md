# Mode C Back-to-Back Operation Fix

In the C09 test, the second Mode C operation first read the previous operation’s source address (`0x8000_0000`) instead of its new source address (`0x8000_0100`).


//code
IDLE: next_state = HREADY ? BUSY : IDLE;

The `IDLE → BUSY` transition previously depended only on `HREADY`. Since `HREADY` could remain high for a while after the first operation, the state machine could enter `BUSY` without a new bus request. I changed the condition to `HBUSREQ && HREADY`, so it enters `BUSY` only when HYDRA is requesting the bus and the bus is ready.

After recompiling the RTL, C09 passed with the correct read sequence and output. Because this transition is shared with Mode B, I also ran the Mode B regression tests T1–T4; all passed. C06–C08 were rerun and passed.