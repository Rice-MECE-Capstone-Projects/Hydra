#!/usr/bin/env python3
"""Train LeNet-5 on MNIST and export one digit's pooling-layer data for the HYDRA benchmark.

Pure numpy (no PyTorch needed). Network (LeNet-5 with ReLU and max pooling):

    32x32 input (28x28 MNIST digit, zero-padded by 2)
    conv1 5x5, 6 maps   -> ReLU -> 6x28x28   -> pool1 2x2 -> 6x14x14
    conv2 5x5, 16 maps  -> ReLU -> 16x10x10  -> pool2 2x2 -> 16x5x5
    fc 400->120 -> ReLU -> fc 120->84 -> ReLU -> fc 84->10

Export (integer data, so HYDRA, the C baseline and this script agree bit for bit):
    pool1 input = conv1 + ReLU computed in integer arithmetic from the uint8 image and
                  conv1 weights quantized by W_SCALE. The C benchmark recomputes it exactly.
    pool2 input = float conv2 + ReLU on the dequantized pool1 output, scaled by ACT_SCALE.
    references  = 2x2 max and 2x2 average (sum >> 2, rounding toward -inf like HYDRA's AVG).

Usage:
    python3 train_export.py                 # train (cached afterwards) and export digit 0
    python3 train_export.py --index 17      # export a different test digit
    python3 train_export.py --retrain       # ignore the cached weights

Outputs (next to this script unless noted):
    mnist/                 downloaded dataset (git-ignored)
    lenet_weights.npz      trained float weights + test accuracy
    lenet_export.npz       image, conv1 maps, pooled maps, label, prediction (for plot_lenet.py)
    ../lenet_data.h        C header included by ../hydra.c
"""
import argparse
import gzip
import time
import urllib.request
from pathlib import Path

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view

HERE = Path(__file__).resolve().parent
MNIST_URL = "https://ossci-datasets.s3.amazonaws.com/mnist/"
MNIST_FILES = {
    "x_train": ("train-images-idx3-ubyte.gz", 16, (60000, 28, 28)),
    "y_train": ("train-labels-idx1-ubyte.gz", 8, (60000,)),
    "x_test": ("t10k-images-idx3-ubyte.gz", 16, (10000, 28, 28)),
    "y_test": ("t10k-labels-idx1-ubyte.gz", 8, (10000,)),
}
W_SCALE = 128      # conv1 weight quantization: w_q = round(w * W_SCALE)
ACT_SCALE = 1024   # pool2 input quantization: a_q = round(a * ACT_SCALE)
POOL = 2


# ---------------------------------------------------------------- data
def load_mnist():
    """Download (once) and parse the four MNIST idx files into numpy arrays."""
    cache = HERE / "mnist"
    cache.mkdir(exist_ok=True)
    data = {}
    for key, (name, header, shape) in MNIST_FILES.items():
        path = cache / name
        if not path.exists():
            print(f"downloading {name}")
            urllib.request.urlretrieve(MNIST_URL + name, path)
        raw = gzip.decompress(path.read_bytes())
        arr = np.frombuffer(raw, dtype=np.uint8, offset=header)
        if arr.size != np.prod(shape):
            raise SystemExit(f"{name}: unexpected size {arr.size}, delete it and rerun")
        data[key] = arr.reshape(shape)
    return data


def pad_images(x):
    """28x28 uint8 -> 32x32 with a 2-pixel zero border (LeNet-5's input size)."""
    return np.pad(x, ((0, 0), (2, 2), (2, 2)))


# ---------------------------------------------------------------- layers
def conv_forward(x, w, b):
    """Valid convolution (cross-correlation). x: N,C,H,W  w: F,C,K,K -> N,F,Ho,Wo."""
    f, c, k, _ = w.shape
    win = sliding_window_view(x, (k, k), axis=(2, 3))            # N,C,Ho,Wo,K,K
    n, _, ho, wo = win.shape[:4]
    cols = win.transpose(0, 2, 3, 1, 4, 5).reshape(n * ho * wo, c * k * k)
    out = cols @ w.reshape(f, -1).T + b
    return out.reshape(n, ho, wo, f).transpose(0, 3, 1, 2), cols


def conv_backward(dout, cols, x_shape, w, need_dx):
    f, c, k, _ = w.shape
    n, _, ho, wo = dout.shape
    d2 = dout.transpose(0, 2, 3, 1).reshape(-1, f)
    dw = (d2.T @ cols).reshape(w.shape)
    db = d2.sum(axis=0)
    dx = None
    if need_dx:
        dcols = (d2 @ w.reshape(f, -1)).reshape(n, ho, wo, c, k, k)
        dx = np.zeros(x_shape, dtype=dout.dtype)
        for ky in range(k):
            for kx in range(k):
                dx[:, :, ky:ky + ho, kx:kx + wo] += dcols[..., ky, kx].transpose(0, 3, 1, 2)
    return dx, dw, db


def pool_forward(x):
    n, c, h, w = x.shape
    return x.reshape(n, c, h // POOL, POOL, w // POOL, POOL).max(axis=(3, 5))


def pool_backward(dout, x, out):
    up = out.repeat(POOL, axis=2).repeat(POOL, axis=3)
    mask = (x == up)
    return mask * dout.repeat(POOL, axis=2).repeat(POOL, axis=3)


# ---------------------------------------------------------------- model
def init_params(rng):
    def he(shape, fan_in):
        return (rng.standard_normal(shape) * np.sqrt(2.0 / fan_in)).astype(np.float32)
    return {
        "c1w": he((6, 1, 5, 5), 25), "c1b": np.zeros(6, np.float32),
        "c2w": he((16, 6, 5, 5), 150), "c2b": np.zeros(16, np.float32),
        "f1w": he((400, 120), 400), "f1b": np.zeros(120, np.float32),
        "f2w": he((120, 84), 120), "f2b": np.zeros(84, np.float32),
        "f3w": he((84, 10), 84), "f3b": np.zeros(10, np.float32),
    }


def forward(p, x, keep=False):
    """x: N,1,32,32 float in [0,1]. Returns logits (and the cache for backprop)."""
    a1, cols1 = conv_forward(x, p["c1w"], p["c1b"])
    r1 = np.maximum(a1, 0)
    p1 = pool_forward(r1)
    a2, cols2 = conv_forward(p1, p["c2w"], p["c2b"])
    r2 = np.maximum(a2, 0)
    p2 = pool_forward(r2)
    flat = p2.reshape(len(x), -1)
    h1 = np.maximum(flat @ p["f1w"] + p["f1b"], 0)
    h2 = np.maximum(h1 @ p["f2w"] + p["f2b"], 0)
    logits = h2 @ p["f3w"] + p["f3b"]
    if not keep:
        return logits
    return logits, (x, cols1, r1, p1, cols2, r2, p2, flat, h1, h2)


def fc_head(p, p2):
    """Classifier from pool2 output (N,16,5,5) -> logits."""
    h1 = np.maximum(p2.reshape(len(p2), -1) @ p["f1w"] + p["f1b"], 0)
    h2 = np.maximum(h1 @ p["f2w"] + p["f2b"], 0)
    return h2 @ p["f3w"] + p["f3b"]


def backward(p, cache, logits, y):
    x, cols1, r1, p1, cols2, r2, p2, flat, h1, h2 = cache
    n = len(y)
    prob = np.exp(logits - logits.max(axis=1, keepdims=True))
    prob /= prob.sum(axis=1, keepdims=True)
    loss = -np.log(prob[np.arange(n), y] + 1e-12).mean()
    d = prob
    d[np.arange(n), y] -= 1
    d /= n
    g = {}
    g["f3w"], g["f3b"] = h2.T @ d, d.sum(0)
    d = (d @ p["f3w"].T) * (h2 > 0)
    g["f2w"], g["f2b"] = h1.T @ d, d.sum(0)
    d = (d @ p["f2w"].T) * (h1 > 0)
    g["f1w"], g["f1b"] = flat.T @ d, d.sum(0)
    d = (d @ p["f1w"].T).reshape(p2.shape)
    d = pool_backward(d, r2, p2) * (r2 > 0)
    d, g["c2w"], g["c2b"] = conv_backward(d, cols2, p1.shape, p["c2w"], need_dx=True)
    d = pool_backward(d, r1, p1) * (r1 > 0)
    _, g["c1w"], g["c1b"] = conv_backward(d, cols1, x.shape, p["c1w"], need_dx=False)
    return loss, g


def accuracy(p, x, y, batch=1000):
    hits = 0
    for i in range(0, len(x), batch):
        hits += (forward(p, x[i:i + batch]).argmax(1) == y[i:i + batch]).sum()
    return hits / len(x)


def train(data, epochs, seed):
    rng = np.random.default_rng(seed)
    p = init_params(rng)
    m = {k: np.zeros_like(v) for k, v in p.items()}
    v = {k: np.zeros_like(v) for k, v in p.items()}
    lr, b1, b2, eps, step = 1e-3, 0.9, 0.999, 1e-8, 0
    x = (pad_images(data["x_train"])[:, None] / 255.0).astype(np.float32)
    y = data["y_train"].astype(np.int64)
    for ep in range(epochs):
        t0, order, losses = time.time(), rng.permutation(len(x)), []
        for i in range(0, len(x), 128):
            idx = order[i:i + 128]
            logits, cache = forward(p, x[idx], keep=True)
            loss, g = backward(p, cache, logits, y[idx])
            losses.append(loss)
            step += 1
            for k in p:
                m[k] = b1 * m[k] + (1 - b1) * g[k]
                v[k] = b2 * v[k] + (1 - b2) * g[k] ** 2
                mh, vh = m[k] / (1 - b1 ** step), v[k] / (1 - b2 ** step)
                p[k] -= (lr * mh / (np.sqrt(vh) + eps)).astype(np.float32)
        print(f"epoch {ep + 1}/{epochs}: loss {np.mean(losses):.4f} ({time.time() - t0:.0f} s)")
    return p


# ---------------------------------------------------------------- export
def pool_int(x, op):
    """2x2 pooling on an integer C,H,W array, matching HYDRA's MAX and AVG (sum >> 2)."""
    c, h, w = x.shape
    blocks = x.reshape(c, h // POOL, POOL, w // POOL, POOL).astype(np.int64)
    if op == "max":
        return blocks.max(axis=(2, 4))
    return blocks.sum(axis=(2, 4)) >> 2  # arithmetic shift = floor, like HYDRA's AVG


def c_array(name, arr, per_line=12):
    flat = np.asarray(arr).reshape(-1)
    lo, hi = int(flat.min()), int(flat.max())
    if lo < -2**31 or hi >= 2**31:
        raise SystemExit(f"{name}: values [{lo}, {hi}] do not fit in int32")
    rows = [", ".join(f"{int(v)}" for v in flat[i:i + per_line])
            for i in range(0, len(flat), per_line)]
    body = ",\n    ".join(rows)
    return f"static const int32_t {name}[{len(flat)}] = {{\n    {body}\n}};\n"


def export(p, data, index, acc):
    img28 = data["x_test"][index]
    label = int(data["y_test"][index])
    img = np.pad(img28, 2).astype(np.int64)                          # 32x32 uint8 values

    # conv1 + ReLU in integer arithmetic (same loop the C benchmark runs)
    w1q = np.round(p["c1w"][:, 0] * W_SCALE).astype(np.int64)        # 6,5,5
    b1q = np.round(p["c1b"] * W_SCALE * 255).astype(np.int64)        # input scale 255
    win = sliding_window_view(img, (5, 5))                            # 28,28,5,5
    conv1 = np.einsum("yxij,fij->fyx", win, w1q) + b1q[:, None, None]
    pool1_in = np.maximum(conv1, 0)                                   # 6,28,28
    pool1_max, pool1_avg = pool_int(pool1_in, "max"), pool_int(pool1_in, "avg")

    # rest of the network in float from the dequantized integer pool1 output
    p1 = pool1_max[None].astype(np.float32) / (W_SCALE * 255)
    a2, _ = conv_forward(p1, p["c2w"], p["c2b"])
    pool2_in = np.round(np.maximum(a2[0], 0) * ACT_SCALE).astype(np.int64)  # 16,10,10
    pool2_max, pool2_avg = pool_int(pool2_in, "max"), pool_int(pool2_in, "avg")

    pred_int = int(fc_head(p, pool2_max[None].astype(np.float32) / ACT_SCALE).argmax())
    pred_float = int(forward(p, (img[None, None] / 255.0).astype(np.float32)).argmax())
    print(f"test digit #{index}: label {label}, float prediction {pred_float}, "
          f"integer-pipeline prediction {pred_int}")

    np.savez(HERE / "lenet_export.npz", image=img28, conv1=pool1_in, pool1_max=pool1_max,
             pool1_avg=pool1_avg, pool2_in=pool2_in, pool2_max=pool2_max, label=label,
             pred=pred_int, pred_float=pred_float, index=index, acc=acc)

    hdr = HERE.parent / "lenet_data.h"
    with open(hdr, "w") as f:
        f.write(f"""// Generated by lenet/train_export.py -- do not edit.
// LeNet-5 (ReLU + 2x2 max pooling) trained on MNIST in numpy, test accuracy {acc * 100:.2f}%.
// Data for MNIST test digit #{index} (label {label}, predicted {pred_int}).
//   lenet_image     32x32 input (28x28 digit zero-padded by 2), uint8 values
//   lenet_conv1_w/b conv1 weights x{W_SCALE} and bias x{W_SCALE * 255}, rounded to integers
//   lenet_pool1_in  6x28x28 integer conv1 + ReLU (exactly what conv1_int() in hydra.c computes)
//   lenet_pool2_in  16x10x10 conv2 + ReLU (float network, scaled by {ACT_SCALE})
//   *_max / *_avg   2x2 max pooling / 2x2 average pooling (sum >> 2) references
#ifndef LENET_DATA_H
#define LENET_DATA_H
#include <stdint.h>

#define LENET_INDEX   {index}
#define LENET_LABEL   {label}
#define LENET_PRED    {pred_int}
#define LENET_ACC_X100 {int(round(acc * 10000))}

#define IMG_DIM   32
#define K1        5
#define C1        6
#define H1        28
#define C2        16
#define H2        10

""")
        f.write(c_array("lenet_image", img))
        f.write(c_array("lenet_conv1_w", w1q))
        f.write(c_array("lenet_conv1_b", b1q))
        f.write(c_array("lenet_pool1_in", pool1_in))
        f.write(c_array("lenet_pool1_max", pool1_max))
        f.write(c_array("lenet_pool1_avg", pool1_avg))
        f.write(c_array("lenet_pool2_in", pool2_in))
        f.write(c_array("lenet_pool2_max", pool2_max))
        f.write(c_array("lenet_pool2_avg", pool2_avg))
        f.write("\n#endif // LENET_DATA_H\n")
    print(f"wrote {hdr}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", type=int, default=0, help="MNIST test image to export")
    ap.add_argument("--epochs", type=int, default=3)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--retrain", action="store_true")
    args = ap.parse_args()

    data = load_mnist()
    wpath = HERE / "lenet_weights.npz"
    if wpath.exists() and not args.retrain:
        saved = dict(np.load(wpath))
        acc = float(saved.pop("acc"))
        p = saved
        print(f"loaded {wpath.name} (test accuracy {acc * 100:.2f}%)")
    else:
        p = train(data, args.epochs, args.seed)
        xt = (pad_images(data["x_test"])[:, None] / 255.0).astype(np.float32)
        acc = float(accuracy(p, xt, data["y_test"]))
        print(f"test accuracy {acc * 100:.2f}%")
        np.savez(wpath, acc=acc, **p)
    export(p, data, args.index, acc)


if __name__ == "__main__":
    main()
