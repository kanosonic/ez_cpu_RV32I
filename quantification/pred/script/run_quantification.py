#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRED_DIR = ROOT / "quantification" / "pred"
RECORD_DIR = PRED_DIR / "record"

DEFAULT_CYCLES = [
    "1M",
    "10M",
    "50M",
    "100M",
    "200M",
    "500M",
    "640M",
    "750M",
    "1000M",
]

METRIC_PATTERNS = {
    "sim_end_reason": re.compile(r"^SIM_END_REASON =\s*(\S+)"),
    "pc": re.compile(r"^PC =\s*(\d+)"),
    "inst_num": re.compile(r"^Number of executed instruction =\s*(\d+)"),
    "cycle_num": re.compile(r"^Number of clock cycles =\s*(\d+)"),
    "cpi": re.compile(r"^CPI =\s*([0-9.]+)"),
    "branch_count": re.compile(r"^BRANCH_COUNT =\s*(\d+)"),
    "branch_taken_count": re.compile(r"^BRANCH_TAKEN_COUNT =\s*(\d+)"),
    "branch_pred_taken_count": re.compile(r"^BRANCH_PRED_TAKEN_COUNT =\s*(\d+)"),
    "branch_pred_correct": re.compile(r"^BRANCH_PRED_CORRECT =\s*(\d+)"),
    "branch_pred_wrong": re.compile(r"^BRANCH_PRED_WRONG =\s*(\d+)"),
    "branch_pred_accuracy": re.compile(r"^BRANCH_PRED_ACCURACY =\s*([0-9.]+)%"),
    "branch_taken_rate": re.compile(r"^BRANCH_TAKEN_RATE =\s*([0-9.]+)%"),
    "branch_pred_taken_rate": re.compile(r"^BRANCH_PRED_TAKEN_RATE =\s*([0-9.]+)%"),
    "branch_mispredict_rate": re.compile(r"^BRANCH_MISPREDICT_RATE =\s*([0-9.]+)%"),
    "jal_count": re.compile(r"^JAL_COUNT =\s*(\d+)"),
    "jal_pred_correct": re.compile(r"^JAL_PRED_CORRECT =\s*(\d+)"),
    "jal_pred_wrong": re.compile(r"^JAL_PRED_WRONG =\s*(\d+)"),
    "jal_pred_accuracy": re.compile(r"^JAL_PRED_ACCURACY =\s*([0-9.]+)%"),
    "ctrl_pred_count": re.compile(r"^CTRL_PRED_COUNT =\s*(\d+)"),
    "ctrl_pred_correct": re.compile(r"^CTRL_PRED_CORRECT =\s*(\d+)"),
    "ctrl_pred_wrong": re.compile(r"^CTRL_PRED_WRONG =\s*(\d+)"),
    "ctrl_pred_accuracy": re.compile(r"^CTRL_PRED_ACCURACY =\s*([0-9.]+)%"),
    "ctrl_mispredict_rate": re.compile(r"^CTRL_MISPREDICT_RATE =\s*([0-9.]+)%"),
}

CSV_FIELDS = [
    "timestamp",
    "strategy",
    "dynamic_prediction",
    "ghr_on",
    "ghr_bits",
    "bht_index_bits",
    "bht_history_bits",
    "cycle_label",
    "max_cycles",
    "status",
    "elapsed_s",
    "sim_end_reason",
    "inst_num",
    "cycle_num",
    "cpi",
    "branch_count",
    "branch_taken_count",
    "branch_pred_taken_count",
    "branch_pred_correct",
    "branch_pred_wrong",
    "branch_pred_accuracy",
    "branch_taken_rate",
    "branch_pred_taken_rate",
    "branch_mispredict_rate",
    "jal_count",
    "jal_pred_accuracy",
    "ctrl_pred_count",
    "ctrl_pred_accuracy",
    "ctrl_mispredict_rate",
    "run_dir",
]


def parse_cycle(value):
    text = str(value).strip().upper()
    if text.endswith("M"):
        return int(text[:-1]) * 1_000_000
    if text.endswith("K"):
        return int(text[:-1]) * 1_000
    return int(text)


def cycle_label(cycles):
    if cycles % 1_000_000 == 0:
        return f"{cycles // 1_000_000}M"
    if cycles % 1_000 == 0:
        return f"{cycles // 1_000}K"
    return str(cycles)


def parse_int_list(text):
    values = []
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        if ":" in item:
            start, end = item.split(":", 1)
            values.extend(range(int(start), int(end) + 1))
        else:
            values.append(int(item))
    return values


def parse_metrics(text):
    metrics = {}
    for line in text.splitlines():
        clean = line.strip()
        for key, pattern in METRIC_PATTERNS.items():
            match = pattern.match(clean)
            if match:
                value = match.group(1)
                if key == "sim_end_reason":
                    metrics[key] = value
                elif "." in value:
                    metrics[key] = float(value)
                else:
                    metrics[key] = int(value)
    return metrics


def strategy_root(strategy):
    if strategy == "static":
        return RECORD_DIR / "static"
    if strategy == "ghr_on":
        return RECORD_DIR / "dynamic" / "ghr_on"
    if strategy == "ghr_off":
        return RECORD_DIR / "dynamic" / "ghr_off"
    raise ValueError(strategy)


def config_name(strategy, ghr_bits, bht_index_bits, bht_history_bits):
    if strategy == "static":
        return "static"
    return f"ghr{ghr_bits}_idx{bht_index_bits}_hist{bht_history_bits}"


def safe_run_id(strategy, cfg_name, label):
    raw = f"pred_{strategy}_{cfg_name}_cycles_{label}"
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", raw)


def iter_configs(args, strategy):
    if strategy == "static":
        yield {
            "strategy": "static",
            "dynamic_prediction": 0,
            "ghr_on": 0,
            "ghr_bits": args.default_ghr_bits,
            "bht_index_bits": args.default_bht_index_bits,
            "bht_history_bits": args.default_bht_history_bits,
        }
    elif strategy == "ghr_off":
        for index_bits in parse_int_list(args.bht_index_bits):
            for history_bits in parse_int_list(args.bht_history_bits):
                yield {
                    "strategy": "ghr_off",
                    "dynamic_prediction": 1,
                    "ghr_on": 0,
                    "ghr_bits": 0,
                    "bht_index_bits": index_bits,
                    "bht_history_bits": history_bits,
                }
    elif strategy == "ghr_on":
        for ghr_bits in parse_int_list(args.ghr_bits):
            for index_bits in parse_int_list(args.bht_index_bits):
                if index_bits <= ghr_bits:
                    continue
                for history_bits in parse_int_list(args.bht_history_bits):
                    yield {
                        "strategy": "ghr_on",
                        "dynamic_prediction": 1,
                        "ghr_on": 1,
                        "ghr_bits": ghr_bits,
                        "bht_index_bits": index_bits,
                        "bht_history_bits": history_bits,
                    }


def run_one(args, config, cycles):
    label = cycle_label(cycles)
    cfg_name = config_name(
        config["strategy"],
        config["ghr_bits"],
        config["bht_index_bits"],
        config["bht_history_bits"],
    )
    run_dir = strategy_root(config["strategy"]) / cfg_name / f"cycles_{label}"
    run_dir.mkdir(parents=True, exist_ok=True)
    metrics_path = run_dir / "metrics.json"
    stdout_path = run_dir / "make_stdout.log"
    raw_log_path = run_dir / "cpu_sim.log"
    run_id = safe_run_id(config["strategy"], cfg_name, label)

    if metrics_path.exists() and not args.force:
        return json.loads(metrics_path.read_text())

    cmd = [
        "make",
        "benchmark",
        f"BENCH_ITERATIONS={args.iterations}",
        f"BENCH_OPT={args.opt}",
        f"BENCH_DATA_SIZE={args.data_size}",
        f"BENCH_MAX_CYCLES={cycles}",
        f"BENCH_SIM_TIMEOUT={args.sim_timeout}",
        f"BENCH_VERILATOR_JOBS={args.verilator_jobs}",
        f"BENCH_DYNAMIC_PREDICTION={config['dynamic_prediction']}",
        f"BENCH_GHR_ON={config['ghr_on']}",
        f"BENCH_BPU_GHR_BITS={config['ghr_bits']}",
        f"BENCH_BPU_BHT_INDEX_BITS={config['bht_index_bits']}",
        f"BENCH_BPU_BHT_HISTORY_BITS={config['bht_history_bits']}",
        f"BENCH_RUN_ID={run_id}",
    ]

    started = time.time()
    proc = subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=os.environ.copy(),
    )
    elapsed = time.time() - started
    stdout_path.write_text(proc.stdout)

    build_log = ROOT / "build" / "benchmark_coremark" / run_id / "cpu_sim.log"
    if build_log.exists():
        raw_log_path.write_text(build_log.read_text(errors="replace"))

    metrics = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "status": "pass" if proc.returncode == 0 else "fail",
        "elapsed_s": round(elapsed, 3),
        "cycle_label": label,
        "max_cycles": cycles,
        "run_dir": str(run_dir.relative_to(ROOT)),
        **config,
    }
    metrics.update(parse_metrics(proc.stdout))
    if proc.returncode != 0:
        metrics["error"] = f"make benchmark exited with {proc.returncode}"

    metrics_path.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n")
    return metrics


def collect_records(root):
    records = []
    for path in sorted(root.rglob("metrics.json")):
        records.append(json.loads(path.read_text()))
    return records


def write_csv(root):
    records = collect_records(root)
    csv_path = root / "results.csv"
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for record in records:
            writer.writerow({field: record.get(field, "") for field in CSV_FIELDS})


def main():
    parser = argparse.ArgumentParser(description="Run CoreMark BPU quantification sweeps.")
    parser.add_argument("--strategy", choices=["static", "ghr_off", "ghr_on", "all"], default="all")
    parser.add_argument("--cycles", default=",".join(DEFAULT_CYCLES))
    parser.add_argument("--ghr-bits", default="0:10")
    parser.add_argument("--bht-index-bits", default="1:12")
    parser.add_argument("--bht-history-bits", default="2")
    parser.add_argument("--default-ghr-bits", type=int, default=8)
    parser.add_argument("--default-bht-index-bits", type=int, default=10)
    parser.add_argument("--default-bht-history-bits", type=int, default=2)
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--data-size", type=int, default=2000)
    parser.add_argument("--opt", default="-O2")
    parser.add_argument("--sim-timeout", type=int, default=7200)
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    parser.add_argument("--verilator-jobs", type=int, default=1)
    parser.add_argument("--limit-configs", type=int, default=0)
    parser.add_argument("--limit-cycles", type=int, default=0)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    strategies = ["static", "ghr_off", "ghr_on"] if args.strategy == "all" else [args.strategy]
    cycles = [parse_cycle(item) for item in args.cycles.split(",") if item.strip()]
    if args.limit_cycles:
        cycles = cycles[: args.limit_cycles]

    for strategy in strategies:
        configs = list(iter_configs(args, strategy))
        if args.limit_configs:
            configs = configs[: args.limit_configs]
        tasks = [(config, cycles_value) for config in configs for cycles_value in cycles]
        with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
            future_to_task = {
                executor.submit(run_one, args, config, cycles_value): (config, cycles_value)
                for config, cycles_value in tasks
            }
            for future in as_completed(future_to_task):
                config, cycles_value = future_to_task[future]
                prefix = (
                    f"[{strategy}] cycles={cycle_label(cycles_value)} "
                    f"ghr={config['ghr_bits']} idx={config['bht_index_bits']} "
                    f"hist={config['bht_history_bits']}"
                )
                try:
                    result = future.result()
                except Exception as exc:
                    print(f"{prefix} failed: {exc}", file=sys.stderr)
                    continue
                print(f"{prefix} {result.get('status', 'unknown')}")
        write_csv(strategy_root(strategy))


if __name__ == "__main__":
    sys.exit(main())
