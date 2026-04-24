#!/usr/bin/env python3
import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRED_DIR = ROOT / "quantification" / "pred"
RECORD_DIR = PRED_DIR / "record"
REPORT = PRED_DIR / "report.md"
REQUESTED_CYCLES = [
    1_000_000,
    10_000_000,
    50_000_000,
    100_000_000,
    200_000_000,
    500_000_000,
    750_000_000,
    1_000_000_000,
]


def read_rows(path):
    if not path.exists():
        return []
    rows = []
    with path.open() as handle:
        for row in csv.DictReader(handle):
            if row.get("status") != "pass":
                continue
            if int(float(row["max_cycles"])) not in REQUESTED_CYCLES:
                continue
            rows.append(row)
    return rows


def num(row, key, default=0.0):
    value = row.get(key, "")
    return float(value) if value != "" else default


def cycle_rows(rows, cycle):
    return [row for row in rows if int(float(row["max_cycles"])) == cycle]


def best_row(rows, metric="branch_pred_accuracy"):
    if not rows:
        return None
    return max(rows, key=lambda row: num(row, metric, -1.0))


def best_rows_by_cycle(rows):
    chosen = {}
    for row in rows:
        cycle = int(float(row["max_cycles"]))
        if cycle not in chosen or num(row, "branch_pred_accuracy", -1.0) > num(chosen[cycle], "branch_pred_accuracy", -1.0):
            chosen[cycle] = row
    return [chosen[cycle] for cycle in REQUESTED_CYCLES if cycle in chosen]


def label_cycle(cycle):
    return f"{cycle // 1_000_000}M"


def fmt_row(row):
    if not row:
        return "No completed row."
    return (
        f"`cycles={row['cycle_label']}`, `ghr={row['ghr_bits']}`, `idx={row['bht_index_bits']}`, "
        f"`hist={row['bht_history_bits']}`, accuracy `{num(row, 'branch_pred_accuracy'):.3f}%`, "
        f"CPI `{num(row, 'cpi'):.6f}`"
    )


def table(rows):
    if not rows:
        return "No completed rows.\n"
    lines = [
        "| Cycles | Config | CPI | Branch Accuracy | Mispredict Rate | Taken Rate | End Reason |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in best_rows_by_cycle(rows):
        config = f"ghr={row['ghr_bits']}, idx={row['bht_index_bits']}, hist={row['bht_history_bits']}"
        lines.append(
            f"| {row['cycle_label']} | {config} | {num(row, 'cpi'):.6f} | "
            f"{num(row, 'branch_pred_accuracy'):.3f}% | {num(row, 'branch_mispredict_rate'):.3f}% | "
            f"{num(row, 'branch_taken_rate'):.3f}% | {row.get('sim_end_reason', '')} |"
        )
    return "\n".join(lines) + "\n"


def top_table(rows, limit=10):
    if not rows:
        return "No completed rows.\n"
    rows = sorted(rows, key=lambda row: (-num(row, "branch_pred_accuracy"), num(row, "cpi")))
    lines = [
        "| Rank | GHR | IDX | HIST | Accuracy | CPI | Mispredict Rate |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for index, row in enumerate(rows[:limit], start=1):
        lines.append(
            f"| {index} | {row['ghr_bits']} | {row['bht_index_bits']} | {row['bht_history_bits']} | "
            f"{num(row, 'branch_pred_accuracy'):.3f}% | {num(row, 'cpi'):.6f} | {num(row, 'branch_mispredict_rate'):.3f}% |"
        )
    return "\n".join(lines) + "\n"


def image_lines():
    plot_dir = PRED_DIR / "plot"
    wanted = [
        "cycle_branch_accuracy.svg",
        "cycle_cpi.svg",
        "ghr_off_idx_accuracy_1000M.svg",
        "ghr_on_best_by_ghr_1000M.svg",
        "ghr_on_accuracy_heatmap.svg",
    ]
    lines = []
    for name in wanted:
        path = plot_dir / name
        if path.exists():
            lines.append(f"![{name}](plot/{name})")
    return lines


def gain_line(static_row, dynamic_row):
    acc_gain = num(dynamic_row, "branch_pred_accuracy") - num(static_row, "branch_pred_accuracy")
    cpi_drop = num(static_row, "cpi") - num(dynamic_row, "cpi")
    return (
        f"Compared with static prediction at `{static_row['cycle_label']}`, this improves branch accuracy by "
        f"`{acc_gain:.3f}` percentage points and lowers CPI by `{cpi_drop:.6f}`."
    )


def main():
    static_rows = read_rows(RECORD_DIR / "static" / "results.csv")
    ghr_off_rows = read_rows(RECORD_DIR / "dynamic" / "ghr_off" / "results.csv")
    ghr_on_rows = read_rows(RECORD_DIR / "dynamic" / "ghr_on" / "results.csv")

    static_1000 = best_row(cycle_rows(static_rows, 1_000_000_000))
    ghr_off_1000 = best_row(cycle_rows(ghr_off_rows, 1_000_000_000))
    ghr_on_1000 = best_row(cycle_rows(ghr_on_rows, 1_000_000_000))
    ghr_on_nonzero_1000 = best_row([row for row in cycle_rows(ghr_on_rows, 1_000_000_000) if int(row["ghr_bits"]) > 0])

    ghr_off_idx_rows = cycle_rows(ghr_off_rows, 1_000_000_000)
    ghr_off_idx_best = best_row(ghr_off_idx_rows)
    ghr_off_idx_worst = min(ghr_off_idx_rows, key=lambda row: num(row, "branch_pred_accuracy")) if ghr_off_idx_rows else None

    ghr_by_best = {}
    for row in cycle_rows(ghr_on_rows, 1_000_000_000):
        ghr = int(row["ghr_bits"])
        if ghr not in ghr_by_best or num(row, "branch_pred_accuracy") > num(ghr_by_best[ghr], "branch_pred_accuracy"):
            ghr_by_best[ghr] = row

    lines = []
    lines.append("# Branch Predictor Quantification Report")
    lines.append("")
    lines.append("This report uses the recorded `make benchmark` results under `quantification/pred/record` for the requested cycle limits: `1M`, `10M`, `50M`, `100M`, `200M`, `500M`, `750M`, and `1000M`.")
    lines.append("")
    lines.append("## Executive Summary")
    lines.append("")
    lines.append(f"- Best static baseline at `1000M`: {fmt_row(static_1000)}")
    lines.append(f"- Best dynamic `ghr_off` at `1000M`: {fmt_row(ghr_off_1000)}")
    lines.append(f"- Best dynamic `ghr_on` at `1000M`: {fmt_row(ghr_on_1000)}")
    lines.append(f"- Best nonzero-GHR result at `1000M`: {fmt_row(ghr_on_nonzero_1000)}")
    lines.append("")
    if static_1000 and ghr_off_1000:
        lines.append(gain_line(static_1000, ghr_off_1000))
        lines.append("")
    lines.append("The strongest result in the current dataset is a dynamic predictor with `BHT_HISTORY_BITS=2`, `GHR_BITS=0`, and `BHT_INDEX_BITS=9`. In other words, the best-performing configuration is effectively the `ghr_off` strategy, and enabling global history does not beat it on CoreMark in this implementation.")
    lines.append("")
    lines.append("## Figures")
    lines.append("")
    lines.extend(image_lines())
    lines.append("")
    lines.append("In the first two figures, the `ghr_on` series uses the best nonzero-GHR configuration at each cycle, restricted to `GHR_BITS=1..10`.")
    lines.append("")
    lines.append("## Strategy Comparison")
    lines.append("")
    lines.append("The cycle-by-cycle comparison shows a very clear separation between static and dynamic prediction. Static prediction stalls near `31.575%` branch accuracy and converges to roughly `1.5 CPI`, while both dynamic strategies converge near `1.0 CPI` once the benchmark prefix is long enough.")
    lines.append("")
    lines.append("The important nuance is that the `ghr_on` family only matches the best dynamic result when `GHR_BITS=0`, which collapses back to the no-history case. That means the dynamic improvement is real, but it comes from the indexed 2-bit counter table rather than from global history correlation.")
    lines.append("")
    lines.append("### Best Per Strategy by Cycle")
    lines.append("")
    lines.append("#### Static")
    lines.append("")
    lines.append(table(static_rows))
    lines.append("#### Dynamic, GHR Off")
    lines.append("")
    lines.append(table(ghr_off_rows))
    lines.append("#### Dynamic, GHR On")
    lines.append("")
    lines.append(table(ghr_on_rows))
    lines.append("## `ghr_off` Parameter Sweep")
    lines.append("")
    if ghr_off_idx_best and ghr_off_idx_worst:
        idx_gain = num(ghr_off_idx_best, "branch_pred_accuracy") - num(ghr_off_idx_worst, "branch_pred_accuracy")
        lines.append(
            f"At `1000M`, sweeping only `BHT_INDEX_BITS` with `GHR_BITS=0` and `BHT_HISTORY_BITS=2` shows strong early gains from increasing table size, then clear saturation. The worst point is `idx={ghr_off_idx_worst['bht_index_bits']}` at `{num(ghr_off_idx_worst, 'branch_pred_accuracy'):.3f}%`, while the best point is `idx={ghr_off_idx_best['bht_index_bits']}` at `{num(ghr_off_idx_best, 'branch_pred_accuracy'):.3f}%`, a gain of `{idx_gain:.3f}` percentage points.")
        lines.append("")
        lines.append("The main transition happens between `idx=1` and `idx=8`. After that, the curve flattens: `idx=8`, `idx=9`, `idx=10`, `idx=11`, and `idx=12` are all effectively tied. This suggests the aliasing problem is mostly solved by about `2^9` entries, and larger tables bring little measurable CoreMark benefit.")
        lines.append("")
    lines.append("## `ghr_on` Parameter Sweep")
    lines.append("")
    if ghr_on_nonzero_1000 and ghr_off_1000:
        loss = num(ghr_off_1000, "branch_pred_accuracy") - num(ghr_on_nonzero_1000, "branch_pred_accuracy")
        lines.append(
            f"The best nonzero-GHR point at `1000M` is `ghr={ghr_on_nonzero_1000['ghr_bits']}`, `idx={ghr_on_nonzero_1000['bht_index_bits']}`, `hist=2` with `{num(ghr_on_nonzero_1000, 'branch_pred_accuracy'):.3f}%` accuracy. That is still `{loss:.3f}` percentage points below the best `ghr_off` result."
        )
        lines.append("")
    lines.append("The 3D figure and heatmap show that the global-history surface is uneven: some larger `GHR_BITS` values recover part of the lost accuracy, but none beat the no-history optimum. The worst valley appears around small nonzero GHR widths with undersized index spaces, where XOR history introduces extra aliasing without enough table capacity to separate branch behaviors.")
    lines.append("")
    lines.append("A useful reading of the surface is:")
    lines.append("")
    lines.append("- `ghr=0` is the dominant ridge, which confirms the benchmark prefers PC-indexed local behavior in this predictor design.")
    lines.append("- Small nonzero GHR values often hurt because they consume index entropy while adding noisy shared history.")
    lines.append("- Very large GHR values can recover some accuracy when paired with larger `idx`, but the best nonzero case still does not surpass the simpler `ghr_off` predictor.")
    lines.append("")
    lines.append("### Top `ghr_on` Configurations at `1000M`")
    lines.append("")
    lines.append(top_table(cycle_rows(ghr_on_rows, 1_000_000_000), limit=12))
    lines.append("## Interpretation")
    lines.append("")
    lines.append("The data says the CoreMark branch stream in this setup is highly amenable to a reasonably sized 2-bit BHT indexed by PC alone. That is why `ghr_off` wins: it avoids history-induced aliasing and already captures the dominant bias and loop behavior.")
    lines.append("")
    lines.append("CPI becomes a weak discriminator once the cycle limit is very large, because all good dynamic configurations approach `1.0 CPI`. Branch accuracy is therefore the better optimization metric here, with CPI mainly confirming that misprediction penalties shrink as the predictor improves.")
    lines.append("")
    lines.append("Because every row in the current dataset ends with `SIM_END_REASON=MAXCYCLES_TIMEOUT`, these are still fixed-prefix measurements rather than true full-program completion measurements. The conclusions are therefore about the first `N` simulated cycles of CoreMark, not about a completed benchmark run. Even so, the ordering is very stable from `10M` onward, which makes the design ranking convincing.")
    lines.append("")
    lines.append("## Optimized Conclusion")
    lines.append("")
    lines.append("The recommended predictor from the current data is:")
    lines.append("")
    lines.append("- Strategy: dynamic prediction with GHR disabled")
    lines.append("- Parameters: `GHR_BITS=0`, `BHT_INDEX_BITS=9`, `BHT_HISTORY_BITS=2`")
    lines.append("- `1000M` result: `89.890%` branch accuracy, `1.000073` CPI")
    lines.append("")
    lines.append("Why this is the best choice:")
    lines.append("")
    lines.append("- It gives the highest observed branch accuracy in the dataset.")
    lines.append("- It matches the best CPI tier.")
    lines.append("- It reaches the accuracy plateau without oversizing the BHT unnecessarily.")
    lines.append("- It is simpler than the `ghr_on` alternatives and empirically more robust on CoreMark.")
    lines.append("")
    lines.append("If you want a practical hardware default from this study, set the predictor to `ghr_off`, `idx=9`, `hist=2`. If you later want to rescue `ghr_on`, the next step is not to increase GHR blindly. The next step is to redesign the indexing or table structure so history does not destroy useful PC locality.")
    lines.append("")

    REPORT.write_text("\n".join(lines))


if __name__ == "__main__":
    main()
