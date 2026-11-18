#!/usr/bin/env python3
"""Summarize Mode E memory-traffic logs (make M=1) into a Markdown table.

Usage: python3 summarize_mem.py [log_dir ...]
       (default: modeE/log modeE_decim/log modeE_pool2d/log, relative to this script)

Reads every *__MEM.log. Each timed kernel is bracketed by bus-monitor markers
(HYDRA: 1 -> 2, SW: 3 -> 4); the snapshots printed on those markers are differenced to get
the AHB beats inside the window, split by master (CPU / HYDRA) and direction. One beat is one
32-bit word (AHBW = 32 on rv32gc). The window-end marker write is itself one CPU write beat
to HYDRA's port, and is subtracted here. The CPU-side columns come from Wally's HPM counters
(instructions retired, D$ accesses, D$ misses) read by the same kernels.

Notes:
  - Dirty D$ lines written back after the window (e.g. during the next cache flush) are not
    counted. In the SW kernel the output stays in the D$, so SW bus writes read as ~0.
  - HYDRA's results go to its own scratchpad, which is not on the shared AHB.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_DIRS = [HERE / "modeE" / "log", HERE / "modeE_decim" / "log", HERE / "modeE_pool2d" / "log"]
BUS_FIELDS = ("cpu_rd", "cpu_wr", "cpu_hy", "hy_rd", "hy_wr")
BUSMON = re.compile(r"BUSMON mark=(\d+) " + " ".join(rf"{f}=(\d+)" for f in BUS_FIELDS))
MEM = re.compile(r"MEM (HYDRA|SW) len=(\d+): instr=(\d+) dacc=(\d+) dmiss=(\d+) dstall=(\d+)")
WINDOWS = {"HYDRA": (1, 2), "SW": (3, 4)}
MARKER_BEATS = {"cpu_wr": 1, "cpu_hy": 1}  # the window-end marker write


def label(log: Path) -> str:
    """Benchmark name from the directory, plus the variant (P / op) from the log name."""
    bench = log.parent.parent.name
    parts = log.stem.split("__")[:-1]  # drop trailing MEM
    extra = [p for p in parts if re.fullmatch(r"P\d+|SUM|AVG|MAX|MIN", p)]
    return " ".join([bench] + extra)


def parse(log: Path):
    snaps, rows = {}, {}
    text = log.read_text(errors="replace")
    if "[FAIL]" in text or "[TRAP]" in text:
        print(f"WARNING: {log} reports a failure", file=sys.stderr)
    for line in text.splitlines():
        m = BUSMON.search(line)
        if m:
            snaps[int(m[1])] = dict(zip(BUS_FIELDS, map(int, m.groups()[1:])))
            continue
        m = MEM.search(line)
        if m:
            who, length = m[1], int(m[2])
            start, end = WINDOWS[who]
            if start not in snaps or end not in snaps:
                print(f"WARNING: {log}: no bus markers for {who} len={length} "
                      "(was it built with M=1?)", file=sys.stderr)
                continue
            bus = {f: snaps[end][f] - snaps[start][f] - MARKER_BEATS.get(f, 0) for f in BUS_FIELDS}
            cpu = dict(zip(("instr", "dacc", "dmiss", "dstall"), map(int, m.groups()[2:])))
            rows.setdefault(length, {})[who] = {**bus, **cpu}
    return rows


def main():
    dirs = [Path(d) for d in sys.argv[1:]] or DEFAULT_DIRS
    logs = sorted(f for d in dirs for f in d.glob("*__MEM.log"))
    if not logs:
        sys.exit("No *__MEM.log files found. Run the benchmarks with `make ... M=1` first.")

    print("| Benchmark | Input words | HYDRA: bus words (HYDRA rd / CPU) | SW: bus words (CPU) "
          "| Bus traffic SW/HYDRA | CPU instr HYDRA / SW | D$ accesses HYDRA / SW "
          "| D$ misses HYDRA / SW | CPU polls of HYDRA |")
    print("|---|---|---|---|---|---|---|---|---|")
    # One row per (benchmark, length); a length measured by several logs (e.g. B=1-1 and B=1-4)
    # gives identical counts, so keep the last one
    table = {}
    for log in logs:
        for length, r in parse(log).items():
            if "HYDRA" in r and "SW" in r:
                table[(label(log), length)] = r
    for (name, length), r in sorted(table.items()):
        h, s = r["HYDRA"], r["SW"]
        h_cpu = h["cpu_rd"] + h["cpu_wr"]
        h_total = h["hy_rd"] + h["hy_wr"] + h_cpu
        s_total = s["cpu_rd"] + s["cpu_wr"] + s["hy_rd"] + s["hy_wr"]
        # CPU beats to HYDRA's port that are reads = STATUS polls (MMR programming is writes)
        polls = h["cpu_hy"] - h["cpu_wr"]
        print(f"| {name} | {length} | {h_total} ({h['hy_rd'] + h['hy_wr']} / {h_cpu}) "
              f"| {s_total} | {s_total / h_total:.2f}x | {h['instr']} / {s['instr']} "
              f"| {h['dacc']} / {s['dacc']} | {h['dmiss']} / {s['dmiss']} | {polls} |")


if __name__ == "__main__":
    main()
