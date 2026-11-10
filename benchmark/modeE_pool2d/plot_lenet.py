#!/usr/bin/env python3
"""Slide figure for the LeNet-5 pooling benchmark.

Left:  the MNIST digit, the 6 conv1 feature maps, and the 6 maps pooled by HYDRA.
Right: cycles for HYDRA vs. the CPU on pool1 and pool2, labelled with the speedup.

Reads lenet/lenet_export.npz (from lenet/train_export.py) and the benchmark logs written by
`make` (and `make DUMP=1`, whose log is kept as log/<S>__<O>__MAX_DUMP.log). If the DUMP log
is present, the pooled maps are drawn from HYDRA's actual scratchpad output.

Usage: python3 plot_lenet.py [--state WICD] [--op MAX] [--out FILE]
"""
import argparse
import re
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec, GridSpecFromSubplotSpec

HERE = Path(__file__).resolve().parent
CYC = re.compile(r"(pool\d): HYDRA = (\d+) cyc, \d+ instr \| SW = (\d+) cyc")
SEG = re.compile(r"pool1 share \(SW\) = ([\d.]+)%")
DUMP = re.compile(r"^# DUMP (\d+) (-?\d+)", re.M)

# Categorical slots 1-2 of the validated reference palette (same as plot_pool_sweep.py)
HYDRA_C, CPU_C = "#2a78d6", "#eb6834"
INK, INK_2, GRID = "#0b0b0b", "#52514e", "#e4e3df"


def read_log(path):
    text = path.read_text()
    if "DONE" not in text or "[FAIL]" in text:
        raise SystemExit(f"{path}: run failed or did not finish")
    cycles = {name: (int(hw), int(sw)) for name, hw, sw in CYC.findall(text)}
    share = SEG.search(text)
    return cycles, (float(share.group(1)) if share else None)


def show_maps(fig, spec, maps, title, cmap):
    """Draw C maps in a 3x2 grid with one shared colour scale."""
    grid = GridSpecFromSubplotSpec(3, 2, subplot_spec=spec, wspace=0.06, hspace=0.06)
    vmax = max(maps.max(), 1)
    for i, m in enumerate(maps):
        ax = fig.add_subplot(grid[i // 2, i % 2])
        ax.imshow(m, cmap=cmap, vmin=0, vmax=vmax, interpolation="nearest")
        ax.set_xticks([]), ax.set_yticks([])
        for s in ax.spines.values():
            s.set_color(GRID)
        if i == 0:
            ax.set_title(title, fontsize=13, color=INK, pad=8, loc="left")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--state", default="WICD")
    ap.add_argument("--opt", default="-O3_-funroll-loops")
    ap.add_argument("--op", default="MAX", choices=["MAX", "AVG"])
    ap.add_argument("--out", type=Path, default=HERE.parent / "hydra_modeE_lenet_pooling.png")
    args = ap.parse_args()

    d = np.load(HERE / "lenet" / "lenet_export.npz")
    cycles, share = read_log(HERE / "log" / f"{args.state}__{args.opt}__{args.op}.log")
    pooled = d["pool1_max" if args.op == "MAX" else "pool1_avg"]
    source = "reference (bit-identical to HYDRA)"
    dump_log = HERE / "log" / f"{args.state}__{args.opt}__{args.op}_DUMP.log"
    if dump_log.exists():
        vals = {int(i): int(v) for i, v in DUMP.findall(dump_log.read_text())}
        if len(vals) == pooled.size:
            hw = np.array([vals[i] for i in range(pooled.size)]).reshape(pooled.shape)
            if not np.array_equal(hw, pooled):
                raise SystemExit("DUMP output differs from the reference")
            pooled, source = hw, "HYDRA scratchpad dump"

    fig = plt.figure(figsize=(16, 9), dpi=150)
    fig.patch.set_facecolor("white")
    outer = GridSpec(1, 2, width_ratios=[1.45, 1], wspace=0.17,
                     left=0.03, right=0.97, top=0.82, bottom=0.14)
    left = GridSpecFromSubplotSpec(1, 3, subplot_spec=outer[0], width_ratios=[1.1, 1, 1],
                                   wspace=0.14)

    ax = fig.add_subplot(left[0])
    ax.imshow(d["image"], cmap="gray_r", interpolation="nearest")
    ax.set_xticks([]), ax.set_yticks([])
    ax.set_title(f"MNIST digit (label {int(d['label'])})", fontsize=13, color=INK, pad=8)
    ax.set_xlabel("28×28 input", fontsize=11, color=INK_2)
    show_maps(fig, left[1], d["conv1"], "conv1 + ReLU: 6×28×28", "Blues")
    show_maps(fig, left[2], pooled, f"pool1 on HYDRA: 6×14×14", "Blues")

    # Cycles per layer, HYDRA vs. CPU
    ax = fig.add_subplot(outer[1])
    layers = ["pool1", "pool2"]
    shapes = {"pool1": "6×28×28 → 6×14×14", "pool2": "16×10×10 → 16×5×5"}
    x = np.arange(len(layers))
    w = 0.36
    cpu = [cycles[l][1] for l in layers]
    hyd = [cycles[l][0] for l in layers]
    ax.bar(x - w / 2 - 0.01, cpu, w, color=CPU_C, label="CPU (RV32 Wally, -O3)", zorder=3)
    ax.bar(x + w / 2 + 0.01, hyd, w, color=HYDRA_C, label="HYDRA Mode E 2D", zorder=3)
    for i, l in enumerate(layers):
        ax.text(x[i] - w / 2, cpu[i], f"{cpu[i]:,}", ha="center", va="bottom", fontsize=11, color=INK_2)
        ax.text(x[i] + w / 2, hyd[i], f"{hyd[i]:,}", ha="center", va="bottom", fontsize=11, color=INK_2)
        ax.text(x[i], max(cpu[i], hyd[i]) * 1.10, f"{cpu[i] / hyd[i]:.2f}× faster",
                ha="center", va="bottom", fontsize=15, fontweight="bold", color=INK)
    ax.set_xticks(x, [f"{l}\n{shapes[l]}" for l in layers], fontsize=12, color=INK)
    ax.set_ylabel("cycles (lower is better)", fontsize=12, color=INK_2)
    ax.set_ylim(0, max(cpu) * 1.30)
    ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:,.0f}"))
    ax.grid(axis="y", color=GRID, zorder=0)
    for s in ["top", "right"]:
        ax.spines[s].set_visible(False)
    for s in ["left", "bottom"]:
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK_2)
    ax.legend(frameon=False, fontsize=11, loc="upper right")
    ax.set_title(f"2×2 {args.op.lower()} pooling cycles", fontsize=13, color=INK, pad=8)

    fig.suptitle("HYDRA Mode E 2D pooling on a trained LeNet-5", fontsize=22,
                 fontweight="bold", color=INK, x=0.03, ha="left", y=0.965)
    fig.text(0.03, 0.895,
             f"Real activations from MNIST test digit #{int(d['index'])} "
             f"(network predicts {int(d['pred'])}, test accuracy {float(d['acc']) * 100:.2f}%). "
             "HYDRA and CPU outputs both match the reference bit for bit.",
             fontsize=13, color=INK_2)
    foot = (f"Wally RV32GC + HYDRA, Questa RTL simulation, {args.state}, -O3 -funroll-loops. "
            "With HYDRA, the CPU never reads the 4,704-word pool1 input.")
    if share is not None:
        foot += f"\nIn software, pool1 is {share:.1f}% of conv1 + pool1 cycles."
    fig.text(0.03, 0.03, foot + f" Pooled maps shown: {source}.", fontsize=11,
             color=INK_2, linespacing=1.5)

    fig.savefig(args.out, facecolor="white")
    print(f"wrote {args.out}")
    for l in layers:
        print(f"{l}: HYDRA {cycles[l][0]} cyc, CPU {cycles[l][1]} cyc, {cycles[l][1] / cycles[l][0]:.2f}x")


if __name__ == "__main__":
    main()
