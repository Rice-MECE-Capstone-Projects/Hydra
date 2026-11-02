#!/usr/bin/env python3
"""Summarize Mode E decimation logs into a Markdown table.

Usage: python3 summarize.py [log_dir]   (default: ./log)

Reads every <S>__<B>__<O>__P<R>__<OP>.log written by the Makefile and prints one row per
(OP, R, len) with HYDRA/SW cycles, speedup, and input/output SNR and SNR gain.
"""
import re
import sys
from pathlib import Path

NAME = re.compile(r"(?P<s>\w+?)__(?P<b>[\d-]+)__(?P<o>.+)__P(?P<r>\d+)__(?P<op>SUM|AVG)\.log$")
CYC = re.compile(r"len = (\d+): HYDRA = (\d+) cyc, \d+ instr \| SW = (\d+) cyc")
SNR = re.compile(r"len = (\d+): SNR in = (-?[\d.]+) dB, SNR out = (-?[\d.]+) dB, "
                 r"SNR GAIN = (-?[\d.]+) dB \(white-noise theory 10log10\(R\) = ([\d.]+) dB\)")


def main():
    log_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "log")
    rows = {}
    for f in sorted(log_dir.glob("*.log")):
        m = NAME.match(f.name)
        if not m:
            continue
        text = f.read_text()
        if "[FAIL]" in text or "[TRAP]" in text:
            print(f"WARNING: {f.name} reports a failure", file=sys.stderr)
        key = (m["s"], m["op"], int(m["r"]))
        for length, hw, sw in CYC.findall(text):
            rows.setdefault(key + (int(length),), {}).update(hw=int(hw), sw=int(sw))
        for length, snr_in, snr_out, gain, theory in SNR.findall(text):
            rows.setdefault(key + (int(length),), {}).update(
                snr_in=snr_in, snr_out=snr_out, gain=gain, theory=theory)

    print("| State | Op | R | Length | HYDRA cyc | SW cyc | Speedup | SNR in (dB) | SNR out (dB) "
          "| SNR gain (dB) | 10log10(R) (dB) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for (s, op, r, length), v in sorted(rows.items()):
        if "hw" not in v or "gain" not in v:
            continue
        print(f"| {s} | {op} | {r} | {length} | {v['hw']} | {v['sw']} | {v['sw'] / v['hw']:.2f}x "
              f"| {v['snr_in']} | {v['snr_out']} | {v['gain']} | {v['theory']} |")


if __name__ == "__main__":
    main()
