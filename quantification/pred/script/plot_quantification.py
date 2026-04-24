#!/usr/bin/env python3
import csv
import math
import sys
from collections import defaultdict
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[3]
PRED_DIR = ROOT / "quantification" / "pred"
RECORD_DIR = PRED_DIR / "record"
PLOT_DIR = PRED_DIR / "plot"
REQUESTED_CYCLES = {
    1_000_000,
    10_000_000,
    50_000_000,
    100_000_000,
    200_000_000,
    500_000_000,
    750_000_000,
    1_000_000_000,
}


def read_csv(path):
    if not path.exists():
        return []
    rows = []
    with path.open() as handle:
        for row in csv.DictReader(handle):
            if row.get("status") != "pass":
                continue
            if as_int(row, "max_cycles") not in REQUESTED_CYCLES:
                continue
            rows.append(row)
    return rows


def as_float(row, key):
    value = row.get(key, "")
    return float(value) if value != "" else math.nan


def as_int(row, key):
    value = row.get(key, "")
    return int(float(value)) if value != "" else 0


def strategy_rows():
    return {
        "static": read_csv(RECORD_DIR / "static" / "results.csv"),
        "ghr_off": read_csv(RECORD_DIR / "dynamic" / "ghr_off" / "results.csv"),
        "ghr_on": read_csv(RECORD_DIR / "dynamic" / "ghr_on" / "results.csv"),
    }


def rows_for_cycle(rows, cycle):
    return [row for row in rows if as_int(row, "max_cycles") == cycle]


def best_per_cycle(rows, metric="branch_pred_accuracy"):
    best = {}
    for row in rows:
        cycle = as_int(row, "max_cycles")
        value = as_float(row, metric)
        if cycle not in best or value > as_float(best[cycle], metric):
            best[cycle] = row
    return [best[cycle] for cycle in sorted(best)]


def nonzero_ghr_rows(rows):
    return [row for row in rows if 1 <= as_int(row, "ghr_bits") <= 10]


def plot_cycle_comparison(rows_by_strategy, plt):
    fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=True)
    normalized = {
        name: nonzero_ghr_rows(rows) if name == "ghr_on" else rows
        for name, rows in rows_by_strategy.items()
    }
    cycle_ticks = sorted({as_int(row, "max_cycles") for rows in normalized.values() for row in best_per_cycle(rows)})
    for name, rows in normalized.items():
        selected = best_per_cycle(rows)
        if not selected:
            continue
        x_values = [as_int(row, "max_cycles") for row in selected]
        accuracy_values = [as_float(row, "branch_pred_accuracy") for row in selected]
        cpi_values = [as_float(row, "cpi") for row in selected]
        axes[0].plot(x_values, accuracy_values, marker="o", label=name)
        axes[1].plot(x_values, cpi_values, marker="o", label=name)
        annotate_series_points(axes[0], x_values, accuracy_values, lambda value: f"{value:.2f}")
        annotate_series_points(axes[1], x_values, cpi_values, lambda value: f"{value:.4f}")

    axes[0].set_ylabel("Branch Accuracy (%)")
    axes[0].set_ylim(20.0, 100.0)
    axes[0].grid(True, alpha=0.3, linestyle="--")
    axes[0].legend()
    axes[1].set_ylabel("CPI")
    axes[1].set_ylim(0.0, 2.0)
    axes[1].set_xlabel("BENCH_MAX_CYCLES")
    axes[0].set_xscale("log")
    axes[1].set_xscale("log")
    axes[1].grid(True, alpha=0.3, linestyle="--")
    if cycle_ticks:
        axes[1].set_xticks(cycle_ticks)
        axes[1].set_xticklabels([format_cycle(value) for value in cycle_ticks])
    axes[1].legend()
    fig.suptitle("CoreMark Predictor Performance vs Simulated Cycles")
    fig.tight_layout()
    fig.savefig(PLOT_DIR / "cycle_accuracy_cpi.png", dpi=160)
    plt.close(fig)


def plot_ghr_parameter(rows, plt):
    if not rows:
        return

    max_cycle = max(as_int(row, "max_cycles") for row in rows)
    rows = [row for row in rows if as_int(row, "max_cycles") == max_cycle]
    by_ghr = defaultdict(list)
    by_index = defaultdict(list)
    for row in rows:
        by_ghr[as_int(row, "ghr_bits")].append(row)
        by_index[as_int(row, "bht_index_bits")].append(row)

    fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=False)
    ghr_bits = sorted(by_ghr)
    best_ghr = [max(by_ghr[key], key=lambda row: as_float(row, "branch_pred_accuracy")) for key in ghr_bits]
    ghr_values = [as_float(row, "branch_pred_accuracy") for row in best_ghr]
    axes[0].plot(ghr_bits, ghr_values, marker="o")
    annotate_series_points(axes[0], ghr_bits, ghr_values, lambda value: f"{value:.2f}")
    axes[0].set_ylabel("Best Branch Accuracy (%)")
    axes[0].set_ylim(0.0, 100.0)
    axes[0].set_xlabel("GHR_BITS")
    axes[0].grid(True, alpha=0.3, linestyle="--")

    index_bits = sorted(by_index)
    best_index = [max(by_index[key], key=lambda row: as_float(row, "branch_pred_accuracy")) for key in index_bits]
    index_values = [as_float(row, "branch_pred_accuracy") for row in best_index]
    axes[1].plot(index_bits, index_values, marker="o")
    annotate_series_points(axes[1], index_bits, index_values, lambda value: f"{value:.2f}")
    axes[1].set_ylabel("Best Branch Accuracy (%)")
    axes[1].set_ylim(0.0, 100.0)
    axes[1].set_xlabel("BHT_INDEX_BITS")
    axes[1].grid(True, alpha=0.3, linestyle="--")
    fig.suptitle(f"GHR-On Parameter Sensitivity at {max_cycle} Cycles")
    fig.tight_layout()
    fig.savefig(PLOT_DIR / "ghr_on_parameter_accuracy.png", dpi=160)
    plt.close(fig)


def plot_ghr_heatmap(rows, plt):
    if not rows:
        return

    max_cycle = max(as_int(row, "max_cycles") for row in rows)
    rows = [row for row in rows if as_int(row, "max_cycles") == max_cycle]
    histories = sorted({as_int(row, "bht_history_bits") for row in rows})
    history = histories[0]
    rows = [row for row in rows if as_int(row, "bht_history_bits") == history]
    ghr_values = sorted({as_int(row, "ghr_bits") for row in rows})
    index_values = sorted({as_int(row, "bht_index_bits") for row in rows})
    value_by_pair = {
        (as_int(row, "ghr_bits"), as_int(row, "bht_index_bits")): as_float(row, "branch_pred_accuracy")
        for row in rows
    }
    matrix = []
    for ghr in ghr_values:
        matrix.append([value_by_pair.get((ghr, index), math.nan) for index in index_values])
    finite_values = [value for row_values in matrix for value in row_values if not math.isnan(value)]
    if not finite_values:
        return
    min_value = min(finite_values)
    max_value = max(finite_values)
    if math.isclose(min_value, max_value):
        max_value = min_value + 1.0

    color_map = plt.matplotlib.colors.LinearSegmentedColormap.from_list(
        "deep_red_yellow_green",
        ["#7f0000", "#d73027", "#fee08b", "#66bd63", "#004d00"],
    )
    fig, axis = plt.subplots(figsize=(10, 6))
    image = axis.imshow(matrix, aspect="auto", origin="lower", vmin=min_value, vmax=max_value, cmap=color_map)
    axis.set_xticks(range(len(index_values)))
    axis.set_xticklabels(index_values)
    axis.set_yticks(range(len(ghr_values)))
    axis.set_yticklabels(ghr_values)
    axis.set_xticks([index - 0.5 for index in range(1, len(index_values))], minor=True)
    axis.set_yticks([index - 0.5 for index in range(1, len(ghr_values))], minor=True)
    axis.grid(which="minor", color="white", linestyle="-", linewidth=1.0)
    for y_index, row_values in enumerate(matrix):
        for x_index, value in enumerate(row_values):
            if math.isnan(value):
                continue
            axis.text(x_index, y_index, f"{value:.1f}", ha="center", va="center", fontsize=8, color="black")
    axis.set_xlabel("BHT_INDEX_BITS")
    axis.set_ylabel("GHR_BITS")
    axis.set_title(f"GHR-On Accuracy Heatmap ({format_cycle(max_cycle)}, hist={history})")
    fig.colorbar(image, ax=axis, label="Branch Accuracy (%)")
    fig.tight_layout()
    fig.savefig(PLOT_DIR / "ghr_on_accuracy_heatmap.png", dpi=160)
    plt.close(fig)


def scale_points(points, width, height, pad, log_x=False):
    if not points:
        return []
    xs = [math.log10(point[0]) if log_x else point[0] for point in points]
    ys = [point[1] for point in points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    if min_x == max_x:
        max_x = min_x + 1
    if min_y == max_y:
        max_y = min_y + 1
    scaled = []
    for (x_raw, y), x in zip(points, xs):
        sx = pad + (x - min_x) * (width - 2 * pad) / (max_x - min_x)
        sy = height - pad - (y - min_y) * (height - 2 * pad) / (max_y - min_y)
        scaled.append((sx, sy, x_raw, y))
    return scaled


def scale_points_with_ranges(points, width, height, pad, x_range=None, y_range=None, log_x=False):
    if not points:
        return []
    xs = [math.log10(point[0]) if log_x else point[0] for point in points]
    ys = [point[1] for point in points]
    if x_range is None:
        min_x, max_x = min(xs), max(xs)
    else:
        min_x, max_x = x_range
        if log_x:
            min_x = math.log10(min_x)
            max_x = math.log10(max_x)
    if y_range is None:
        min_y, max_y = min(ys), max(ys)
    else:
        min_y, max_y = y_range
    if min_x == max_x:
        max_x = min_x + 1
    if min_y == max_y:
        max_y = min_y + 1
    scaled = []
    for (x_raw, y), x in zip(points, xs):
        sx = pad + (x - min_x) * (width - 2 * pad) / (max_x - min_x)
        sy = height - pad - (y - min_y) * (height - 2 * pad) / (max_y - min_y)
        scaled.append((sx, sy, x_raw, y))
    return scaled


def format_value(value):
    if math.isnan(value):
        return "nan"
    if abs(value) >= 100:
        return f"{value:.2f}"
    if abs(value) >= 10:
        return f"{value:.3f}"
    return f"{value:.4f}"


def y_ticks_from_series(series, tick_count=6, y_range=None):
    if y_range is not None:
        min_value, max_value = y_range
        return [min_value + (max_value - min_value) * index / (tick_count - 1) for index in range(tick_count)]
    values = [
        point[1]
        for points in series.values()
        for point in points
        if points and not math.isnan(point[1])
    ]
    if not values:
        return [0.0, 1.0]
    min_value = min(values)
    max_value = max(values)
    if math.isclose(min_value, max_value):
        padding = max(abs(min_value) * 0.05, 1.0)
        min_value -= padding
        max_value += padding
    else:
        padding = (max_value - min_value) * 0.08
        min_value -= padding
        max_value += padding
    return [min_value + (max_value - min_value) * index / (tick_count - 1) for index in range(tick_count)]


def annotate_series_points(axis, x_values, y_values, formatter):
    for x_value, y_value in zip(x_values, y_values):
        axis.annotate(
            formatter(y_value),
            (x_value, y_value),
            textcoords="offset points",
            xytext=(0, 7),
            ha="center",
            fontsize=8,
        )


def line_series_style(name, index):
    colors = ["#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#ff7f0e"]
    color = colors[index % len(colors)]
    style = {
        "color": color,
        "dasharray": None,
        "marker_fill": color,
        "marker_stroke": "none",
        "marker_stroke_width": 0,
        "label_dy": -10,
        "legend_fill": color,
        "legend_stroke": "none",
        "legend_stroke_width": 0,
    }
    if name == "ghr_on":
        style.update(
            {
                "dasharray": "8 5",
                "marker_fill": "white",
                "marker_stroke": color,
                "marker_stroke_width": 2,
                "label_dy": 16,
                "legend_fill": "white",
                "legend_stroke": color,
                "legend_stroke_width": 2,
            }
        )
    return style


def write_line_svg(path, title, series, y_label, x_label="BENCH_MAX_CYCLES", x_value_label=None, log_x=True, y_range=None):
    width, height, pad = 900, 520, 70
    x_values = sorted({point[0] for points in series.values() for point in points})
    x_range = (min(x_values), max(x_values)) if x_values else (0, 1)
    x_value_label = x_value_label or x_label
    y_ticks = y_ticks_from_series(series, y_range=y_range)
    scaled_y_ticks = scale_points_with_ranges(
        [(x_values[0] if x_values else 0, value) for value in y_ticks],
        width,
        height,
        pad,
        x_range=x_range,
        y_range=y_range,
        log_x=log_x,
    )
    scaled_x_ticks = scale_points_with_ranges(
        [(value, y_ticks[0]) for value in x_values],
        width,
        height,
        pad,
        x_range=x_range,
        y_range=y_range,
        log_x=log_x,
    )
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width / 2}" y="30" text-anchor="middle" font-size="20">{escape(title)}</text>',
        f'<line x1="{pad}" y1="{height - pad}" x2="{width - pad}" y2="{height - pad}" stroke="black"/>',
        f'<line x1="{pad}" y1="{pad}" x2="{pad}" y2="{height - pad}" stroke="black"/>',
        f'<text x="{width / 2}" y="{height - 20}" text-anchor="middle">{escape(x_label)}</text>',
        f'<text x="20" y="{height / 2}" transform="rotate(-90 20,{height / 2})" text-anchor="middle">{escape(y_label)}</text>',
    ]
    for _, y, _, value in scaled_y_ticks:
        parts.append(
            f'<line x1="{pad}" y1="{y:.2f}" x2="{width - pad}" y2="{y:.2f}" stroke="#d0d0d0" stroke-dasharray="4 4"/>'
        )
        parts.append(f'<text x="{pad - 10}" y="{y + 4:.2f}" text-anchor="end" font-size="11">{format_value(value)}</text>')
    for x, _, raw_x, _ in scaled_x_ticks:
        parts.append(
            f'<line x1="{x:.2f}" y1="{pad}" x2="{x:.2f}" y2="{height - pad}" stroke="#e2e2e2" stroke-dasharray="4 4"/>'
        )
        parts.append(
            f'<text x="{x:.2f}" y="{height - pad + 22}" text-anchor="middle" font-size="11">{format_cycle(raw_x) if log_x else raw_x}</text>'
        )
    for index, (name, points) in enumerate(series.items()):
        scaled = scale_points_with_ranges(points, width, height, pad, x_range=x_range, y_range=y_range, log_x=log_x)
        if not scaled:
            continue
        style = line_series_style(name, index)
        color = style["color"]
        polyline = " ".join(f"{x:.2f},{y:.2f}" for x, y, _, _ in scaled)
        dash = f' stroke-dasharray="{style["dasharray"]}"' if style["dasharray"] else ""
        parts.append(f'<polyline fill="none" stroke="{color}" stroke-width="2"{dash} points="{polyline}"/>')
        for x, y, x_raw, y_raw in scaled:
            parts.append(
                f'<circle cx="{x:.2f}" cy="{y:.2f}" r="4" fill="{style["marker_fill"]}" stroke="{style["marker_stroke"]}" stroke-width="{style["marker_stroke_width"]}"/>'
            )
            parts.append(f'<title>{escape(name)}: {escape(x_value_label)}={x_raw}, value={y_raw:.4f}</title>')
            parts.append(
                f'<text x="{x:.2f}" y="{y + style["label_dy"]:.2f}" text-anchor="middle" font-size="10" fill="{color}">{format_value(y_raw)}</text>'
            )
        legend_y = 58 + 22 * index
        parts.append(
            f'<rect x="{width - 210}" y="{legend_y - 12}" width="14" height="14" fill="{style["legend_fill"]}" stroke="{style["legend_stroke"]}" stroke-width="{style["legend_stroke_width"]}"/>'
        )
        parts.append(f'<text x="{width - 190}" y="{legend_y}" font-size="14">{escape(name)}</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts))


def format_cycle(cycle):
    if cycle % 1_000_000 == 0:
        return f"{cycle // 1_000_000}M"
    return str(cycle)


def heatmap_color(value, min_value, max_value):
    if value is None or math.isnan(value):
        return "#eeeeee"
    ratio = 0.0 if math.isclose(min_value, max_value) else (value - min_value) / (max_value - min_value)
    ratio = max(0.0, min(1.0, ratio))
    ratio = math.pow(ratio, 0.50)
    if ratio < 0.5:
        local = ratio / 0.5
        red = int(127 + 128 * local)
        green = int(0 + 224 * local)
        blue = int(0 + 139 * local)
    else:
        local = (ratio - 0.5) / 0.5
        red = int(255 - 255 * local)
        green = int(224 - 47 * local)
        blue = int(139 * (1 - local))
    return f"#{red:02x}{green:02x}{blue:02x}"


def write_heatmap_svg(path, rows):
    if not rows:
        return
    max_cycle = max(as_int(row, "max_cycles") for row in rows)
    rows = [row for row in rows if as_int(row, "max_cycles") == max_cycle]
    histories = sorted({as_int(row, "bht_history_bits") for row in rows})
    history = histories[0]
    rows = [row for row in rows if as_int(row, "bht_history_bits") == history]
    ghr_values = sorted({as_int(row, "ghr_bits") for row in rows})
    index_values = sorted({as_int(row, "bht_index_bits") for row in rows})
    values = [as_float(row, "branch_pred_accuracy") for row in rows]
    if not values:
        return
    min_value, max_value = min(values), max(values)
    if math.isclose(min_value, max_value):
        max_value = min_value + 1.0
    by_pair = {
        (as_int(row, "ghr_bits"), as_int(row, "bht_index_bits")): as_float(row, "branch_pred_accuracy")
        for row in rows
    }
    cell, pad = 44, 90
    width = pad + cell * len(index_values) + 30
    height = pad + cell * len(ghr_values) + 70
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width / 2}" y="30" text-anchor="middle" font-size="18">GHR-On Accuracy Heatmap ({format_cycle(max_cycle)}, hist={history})</text>',
    ]
    for y_index, ghr in enumerate(ghr_values):
        for x_index, index_bits in enumerate(index_values):
            value = by_pair.get((ghr, index_bits))
            color = heatmap_color(value, min_value, max_value)
            x = pad + x_index * cell
            y = pad + (len(ghr_values) - 1 - y_index) * cell
            parts.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" fill="{color}" stroke="#ffffff"/>')
            if value is not None:
                parts.append(f'<text x="{x + cell / 2}" y="{y + cell / 2 + 5}" text-anchor="middle" font-size="10">{value:.1f}</text>')
    for x_index in range(len(index_values) + 1):
        x = pad + x_index * cell
        parts.append(f'<line x1="{x}" y1="{pad}" x2="{x}" y2="{pad + cell * len(ghr_values)}" stroke="#d0d0d0"/>')
    for y_index in range(len(ghr_values) + 1):
        y = pad + y_index * cell
        parts.append(f'<line x1="{pad}" y1="{y}" x2="{pad + cell * len(index_values)}" y2="{y}" stroke="#d0d0d0"/>')
    for x_index, index_bits in enumerate(index_values):
        x = pad + x_index * cell + cell / 2
        parts.append(f'<text x="{x}" y="{height - 30}" text-anchor="middle" font-size="12">{index_bits}</text>')
    for y_index, ghr in enumerate(ghr_values):
        y = pad + (len(ghr_values) - 1 - y_index) * cell + cell / 2
        parts.append(f'<text x="{pad - 20}" y="{y + 5}" text-anchor="end" font-size="12">{ghr}</text>')
    parts.append(f'<text x="{width / 2}" y="{height - 8}" text-anchor="middle">BHT_INDEX_BITS</text>')
    parts.append(f'<text x="20" y="{height / 2}" transform="rotate(-90 20,{height / 2})" text-anchor="middle">GHR_BITS</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts))


def write_idx_sweep_svg(path, rows, cycle):
    rows = rows_for_cycle(rows, cycle)
    rows = sorted(rows, key=lambda row: as_int(row, "bht_index_bits"))
    series = {
        "ghr_off": [
            (as_int(row, "bht_index_bits"), as_float(row, "branch_pred_accuracy")) for row in rows
        ]
    }
    write_line_svg(
        path,
        f"GHR-Off Accuracy vs BHT_INDEX_BITS at {format_cycle(cycle)}",
        series,
        "Branch Accuracy (%)",
        x_label="BHT_INDEX_BITS",
        x_value_label="bht_index_bits",
        log_x=False,
        y_range=(0.0, 100.0),
    )


def write_best_by_ghr_svg(path, rows, cycle):
    rows = rows_for_cycle(rows, cycle)
    by_ghr = defaultdict(list)
    for row in rows:
        by_ghr[as_int(row, "ghr_bits")].append(row)
    series = {
        "best_per_ghr": [
            (
                ghr,
                as_float(max(by_ghr[ghr], key=lambda row: as_float(row, "branch_pred_accuracy")), "branch_pred_accuracy"),
            )
            for ghr in sorted(by_ghr)
        ]
    }
    write_line_svg(
        path,
        f"GHR-On Best Accuracy vs GHR_BITS at {format_cycle(cycle)}",
        series,
        "Branch Accuracy (%)",
        x_label="GHR_BITS",
        x_value_label="ghr_bits",
        log_x=False,
        y_range=(0.0, 100.0),
    )


def project_3d(x, y, z, x_range, y_range, z_range, width, height, pad):
    x_min, x_max = x_range
    y_min, y_max = y_range
    z_min, z_max = z_range
    nx = 0 if x_max == x_min else (x - x_min) / (x_max - x_min)
    ny = 0 if y_max == y_min else (y - y_min) / (y_max - y_min)
    nz = 0 if z_max == z_min else (z - z_min) / (z_max - z_min)
    plane_w = width - 2 * pad
    plane_h = height - 2 * pad
    origin_x = pad + plane_w * 0.18
    origin_y = height - pad * 1.2
    x_axis = (plane_w * 0.52, -plane_h * 0.16)
    y_axis = (plane_w * 0.28, -plane_h * 0.34)
    z_axis = (0, -plane_h * 0.52)
    px = origin_x + nx * x_axis[0] + ny * y_axis[0] + nz * z_axis[0]
    py = origin_y + nx * x_axis[1] + ny * y_axis[1] + nz * z_axis[1]
    return px, py


def write_3d_svg(path, rows, cycle):
    rows = rows_for_cycle(rows, cycle)
    if not rows:
        return
    width, height, pad = 980, 680, 90
    xs = sorted({as_int(row, "ghr_bits") for row in rows})
    ys = sorted({as_int(row, "bht_index_bits") for row in rows})
    zs = [as_float(row, "branch_pred_accuracy") for row in rows]
    x_range = (min(xs), max(xs))
    y_range = (min(ys), max(ys))
    z_range = (0.0, 100.0)

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width / 2}" y="34" text-anchor="middle" font-size="22">GHR-On 3D Accuracy Surface at {format_cycle(cycle)}</text>',
    ]

    ox, oy = project_3d(x_range[0], y_range[0], z_range[0], x_range, y_range, z_range, width, height, pad)
    xx, xy = project_3d(x_range[1], y_range[0], z_range[0], x_range, y_range, z_range, width, height, pad)
    yx, yy = project_3d(x_range[0], y_range[1], z_range[0], x_range, y_range, z_range, width, height, pad)
    zx, zy = project_3d(x_range[0], y_range[0], z_range[1], x_range, y_range, z_range, width, height, pad)
    parts.extend(
        [
            f'<line x1="{ox:.1f}" y1="{oy:.1f}" x2="{xx:.1f}" y2="{xy:.1f}" stroke="#222" stroke-width="2"/>',
            f'<line x1="{ox:.1f}" y1="{oy:.1f}" x2="{yx:.1f}" y2="{yy:.1f}" stroke="#222" stroke-width="2"/>',
            f'<line x1="{ox:.1f}" y1="{oy:.1f}" x2="{zx:.1f}" y2="{zy:.1f}" stroke="#222" stroke-width="2"/>',
            f'<text x="{xx + 16:.1f}" y="{xy + 6:.1f}" font-size="14">GHR_BITS</text>',
            f'<text x="{yx - 10:.1f}" y="{yy - 8:.1f}" font-size="14">BHT_INDEX_BITS</text>',
            f'<text x="{zx - 8:.1f}" y="{zy - 12:.1f}" font-size="14">Accuracy (%)</text>',
        ]
    )

    for ghr in xs:
        gx0, gy0 = project_3d(ghr, y_range[0], z_range[0], x_range, y_range, z_range, width, height, pad)
        gx1, gy1 = project_3d(ghr, y_range[1], z_range[0], x_range, y_range, z_range, width, height, pad)
        parts.append(f'<line x1="{gx0:.1f}" y1="{gy0:.1f}" x2="{gx1:.1f}" y2="{gy1:.1f}" stroke="#dcdcdc" stroke-dasharray="4 4"/>')
    for idx in ys:
        ix0, iy0 = project_3d(x_range[0], idx, z_range[0], x_range, y_range, z_range, width, height, pad)
        ix1, iy1 = project_3d(x_range[1], idx, z_range[0], x_range, y_range, z_range, width, height, pad)
        parts.append(f'<line x1="{ix0:.1f}" y1="{iy0:.1f}" x2="{ix1:.1f}" y2="{iy1:.1f}" stroke="#dcdcdc" stroke-dasharray="4 4"/>')
    z_ticks = [z_range[0] + (z_range[1] - z_range[0]) * index / 4 for index in range(5)]
    for value in z_ticks:
        zx0, zy0 = project_3d(x_range[0], y_range[0], value, x_range, y_range, z_range, width, height, pad)
        zx1, zy1 = project_3d(x_range[1], y_range[0], value, x_range, y_range, z_range, width, height, pad)
        parts.append(f'<line x1="{zx0:.1f}" y1="{zy0:.1f}" x2="{zx1:.1f}" y2="{zy1:.1f}" stroke="#e0e0e0" stroke-dasharray="3 5"/>')
        parts.append(f'<text x="{zx0 - 12:.1f}" y="{zy0 + 4:.1f}" text-anchor="end" font-size="11">{value:.2f}</text>')

    for ghr in xs:
        line = []
        for idx in ys:
            row = next((r for r in rows if as_int(r, "ghr_bits") == ghr and as_int(r, "bht_index_bits") == idx), None)
            if row is None:
                continue
            line.append(project_3d(ghr, idx, as_float(row, "branch_pred_accuracy"), x_range, y_range, z_range, width, height, pad))
        if len(line) >= 2:
            pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in line)
            parts.append(f'<polyline fill="none" stroke="#7aa6c2" stroke-width="1.3" points="{pts}"/>')

    for idx in ys:
        line = []
        for ghr in xs:
            row = next((r for r in rows if as_int(r, "ghr_bits") == ghr and as_int(r, "bht_index_bits") == idx), None)
            if row is None:
                continue
            line.append(project_3d(ghr, idx, as_float(row, "branch_pred_accuracy"), x_range, y_range, z_range, width, height, pad))
        if len(line) >= 2:
            pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in line)
            parts.append(f'<polyline fill="none" stroke="#d7c0a0" stroke-width="1.1" points="{pts}"/>')

    for row in sorted(rows, key=lambda r: as_float(r, "branch_pred_accuracy")):
        ghr = as_int(row, "ghr_bits")
        idx = as_int(row, "bht_index_bits")
        acc = as_float(row, "branch_pred_accuracy")
        x, y = project_3d(ghr, idx, acc, x_range, y_range, z_range, width, height, pad)
        ratio = (acc - z_range[0]) / (z_range[1] - z_range[0] if z_range[1] != z_range[0] else 1)
        red = int(245 - 110 * ratio)
        green = int(120 + 90 * ratio)
        blue = int(90 + 90 * ratio)
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4.3" fill="#{red:02x}{green:02x}{blue:02x}" stroke="#333"/>')
        parts.append(
            f'<title>ghr={ghr}, idx={idx}, accuracy={acc:.3f}%, cpi={as_float(row, "cpi"):.6f}</title>'
        )
        parts.append(f'<text x="{x + 7:.1f}" y="{y - 7:.1f}" font-size="9">{acc:.2f}</text>')

    for ghr in xs:
        x, y = project_3d(ghr, y_range[0], z_range[0], x_range, y_range, z_range, width, height, pad)
        parts.append(f'<text x="{x:.1f}" y="{y + 18:.1f}" text-anchor="middle" font-size="11">{ghr}</text>')
    for idx in ys:
        x, y = project_3d(x_range[0], idx, z_range[0], x_range, y_range, z_range, width, height, pad)
        parts.append(f'<text x="{x - 18:.1f}" y="{y + 4:.1f}" text-anchor="end" font-size="11">{idx}</text>')

    best = max(rows, key=lambda row: as_float(row, "branch_pred_accuracy"))
    bx, by = project_3d(
        as_int(best, "ghr_bits"),
        as_int(best, "bht_index_bits"),
        as_float(best, "branch_pred_accuracy"),
        x_range,
        y_range,
        z_range,
        width,
        height,
        pad,
    )
    parts.append(f'<circle cx="{bx:.1f}" cy="{by:.1f}" r="6.5" fill="none" stroke="#111" stroke-width="2"/>')
    parts.append(
        f'<text x="{bx + 10:.1f}" y="{by - 8:.1f}" font-size="13">best: ghr={best["ghr_bits"]}, idx={best["bht_index_bits"]}, acc={as_float(best,"branch_pred_accuracy"):.3f}%</text>'
    )

    parts.append("</svg>")
    path.write_text("\n".join(parts))


def fallback_plots(rows):
    acc_series = {}
    cpi_series = {}
    for name, strategy_rows_value in rows.items():
        if name == "ghr_on":
            strategy_rows_value = nonzero_ghr_rows(strategy_rows_value)
        selected = best_per_cycle(strategy_rows_value)
        acc_series[name] = [
            (as_int(row, "max_cycles"), as_float(row, "branch_pred_accuracy")) for row in selected
        ]
        cpi_series[name] = [(as_int(row, "max_cycles"), as_float(row, "cpi")) for row in selected]
    write_line_svg(
        PLOT_DIR / "cycle_branch_accuracy.svg",
        "Branch Accuracy vs Cycles",
        acc_series,
        "Branch Accuracy (%)",
        y_range=(20.0, 100.0),
    )
    write_line_svg(PLOT_DIR / "cycle_cpi.svg", "CPI vs Cycles", cpi_series, "CPI", y_range=(0.0, 2.0))
    write_idx_sweep_svg(PLOT_DIR / "ghr_off_idx_accuracy_1000M.svg", rows["ghr_off"], 1_000_000_000)
    write_best_by_ghr_svg(PLOT_DIR / "ghr_on_best_by_ghr_1000M.svg", rows["ghr_on"], 1_000_000_000)

    ghr_rows = rows["ghr_on"]
    if ghr_rows:
        max_cycle = max(as_int(row, "max_cycles") for row in ghr_rows)
        current = [row for row in ghr_rows if as_int(row, "max_cycles") == max_cycle]
        by_ghr = defaultdict(list)
        by_index = defaultdict(list)
        for row in current:
            by_ghr[as_int(row, "ghr_bits")].append(row)
            by_index[as_int(row, "bht_index_bits")].append(row)
        series = {
            "best_by_ghr": [
                (key, as_float(max(value, key=lambda row: as_float(row, "branch_pred_accuracy")), "branch_pred_accuracy"))
                for key, value in sorted(by_ghr.items())
            ],
            "best_by_bht_index": [
                (key, as_float(max(value, key=lambda row: as_float(row, "branch_pred_accuracy")), "branch_pred_accuracy"))
                for key, value in sorted(by_index.items())
            ],
        }
        write_line_svg(
            PLOT_DIR / "ghr_on_parameter_accuracy.svg",
            f"GHR-On Parameter Sensitivity at {max_cycle} Cycles",
            series,
            "Best Branch Accuracy (%)",
            log_x=False,
            y_range=(0.0, 100.0),
        )
        write_heatmap_svg(PLOT_DIR / "ghr_on_accuracy_heatmap.svg", ghr_rows)


def main():
    PLOT_DIR.mkdir(parents=True, exist_ok=True)
    rows = strategy_rows()
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception as exc:
        print(f"matplotlib is required for plotting: {exc}", file=sys.stderr)
        fallback_plots(rows)
        return 0

    plot_cycle_comparison(rows, plt)
    plot_ghr_parameter(rows["ghr_on"], plt)
    plot_ghr_heatmap(rows["ghr_on"], plt)
    return 0


if __name__ == "__main__":
    sys.exit(main())
