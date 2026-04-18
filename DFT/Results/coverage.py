import matplotlib.pyplot as plt
import numpy as np

# Data
methods = [
    "Baseline",
    "Expanded\nSampling",
    "Multiple\nIterations",
    "Random\nPatterns"
]
coverage = [52.31, 59.33, 64.63, 70.73]

x = np.arange(len(methods))

# Figure
plt.figure(figsize=(8, 4))
ax = plt.gca()

# Bar colors: muted academic style
bar_colors = ['#c44e52', '#7f7f7f', '#9a9a9a', '#4c72b0']

# Bars
ax.bar(x, coverage, width=0.38, color=bar_colors, edgecolor='black', linewidth=0.8, zorder=2)

# Trend line
ax.plot(x, coverage, color='black', marker='o', markersize=4.5, linewidth=1.2, zorder=3)

# Value labels
for i, v in enumerate(coverage):
    ax.text(i, v + 1.0, f"{v:.2f}%", ha='center', va='bottom', fontsize=11)

# Axes / labels
ax.set_xticks(x)
ax.set_xticklabels(methods, fontsize=11)
ax.set_ylabel("Fault Coverage (%)", fontsize=13)
ax.set_title("ATPG Coverage Improvement", fontsize=15, pad=10)

# Y range and ticks
ax.set_ylim(0, 80)
ax.set_yticks(np.arange(0, 81, 10))
ax.tick_params(axis='y', labelsize=11)

# Light horizontal grid only
ax.grid(axis='y', linestyle='--', linewidth=0.6, alpha=0.5, zorder=1)
ax.grid(axis='x', visible=False)

# Spine styling
for spine in ax.spines.values():
    spine.set_linewidth(1.0)

plt.tight_layout()
plt.show()