from __future__ import annotations

import os
from typing import List, cast

import matplotlib.pyplot as plt
import pandas as pd

BASE_DIR = os.path.dirname(__file__)
OUT_DIR = os.path.join(BASE_DIR, ".out")
CSV_PATH = os.path.join(OUT_DIR, "results.csv")

COLOR_MAP = {
    "kiri-rust": "tab:blue",
    "kiri-swift": "tab:orange",
    "rust": "tab:blue",
    "swift": "tab:orange",
    "axum": "tab:green",
    "vapor": "tab:purple",
    "gin": "tab:cyan",
}


def main() -> None:
    if not os.path.exists(CSV_PATH):
        raise SystemExit(f"Missing {CSV_PATH}. Run the parser first.")

    df = pd.read_csv(CSV_PATH)

    # Filter ok == "1"
    df["ok"] = df["ok"].astype(str)
    df = df.loc[df["ok"] == "1"].copy()

    # Numeric conversions
    df["rps"] = pd.to_numeric(df["rps"], errors="coerce")
    if "latency_ms" in df.columns:
        df["latency_ms"] = pd.to_numeric(df["latency_ms"], errors="coerce")
    else:
        df["latency_ms"] = pd.NA

    # Aggregate medians
    agg = (
        df.groupby(["endpoint", "impl", "threads", "connections"], dropna=False)
        .agg(
            rps_median=("rps", "median"),
            lat_median=("latency_ms", "median"),
            runs=("rps", "count"),
        )
        .reset_index()
    )

    os.makedirs(OUT_DIR, exist_ok=True)

    plot_metric_all(
        agg=agg,
        metric_col="rps_median",
        ylabel="Requests/sec (median)",
        title_prefix="Throughput",
        out_name="throughput.png",
    )

    # Plot latency only if there is at least one non-NaN value
    lat_series = cast(pd.Series, agg["lat_median"])
    if lat_series.notna().any():  # any() is a bool, pyright-safe
        plot_metric_all(
            agg=agg,
            metric_col="lat_median",
            ylabel="Latency ms (median)",
            title_prefix="Latency",
            out_name="latency.png",
        )

    print("Saved plots into .out/ (png files).")


def plot_metric_all(
    *,
    agg: pd.DataFrame,
    metric_col: str,
    ylabel: str,
    title_prefix: str,
    out_name: str,
) -> None:
    endpoints = sorted(cast(List[str], agg["endpoint"].dropna().unique().tolist()))

    if not endpoints:
        return

    pairs = sorted(
        cast(
            List[tuple],
            agg[["endpoint", "connections"]]
            .dropna()
            .drop_duplicates()
            .itertuples(index=False, name=None),
        )
    )
    if not pairs:
        return

    fig, axes = plt.subplots(
        nrows=len(pairs),
        ncols=1,
        figsize=(9, 2.8 * len(pairs)),
        sharex=False,
    )
    if len(pairs) == 1:
        axes = [axes]

    for ax, (endpoint, connections) in zip(axes, pairs):
        sub_ec = cast(
            pd.DataFrame,
            agg.loc[
                (agg["endpoint"] == endpoint) & (agg["connections"] == connections)
            ],
        )

        pivot_tbl = cast(
            pd.DataFrame,
            sub_ec.pivot_table(
                index="threads",
                columns="impl",
                values=metric_col,
                aggfunc="first",
            ).sort_index(),
        )

        threads = cast(List[int], pivot_tbl.index.tolist())
        impls = cast(List[str], pivot_tbl.columns.tolist())
        impls = _ordered_impls(impls)

        group_gap = 1.2
        x_positions = [i * group_gap for i in range(len(threads))]
        bar_width = 0.8 / max(1, len(impls))

        for i, impl in enumerate(impls):
            offset = (i - (len(impls) - 1) / 2) * bar_width
            ax.bar(
                [x + offset for x in x_positions],
                pivot_tbl[impl],
                width=bar_width,
                label=impl,
                color=COLOR_MAP.get(impl),
            )

        ax.set_ylabel(ylabel)
        ax.set_title(
            f"{title_prefix} — endpoint={endpoint} — connections={connections}"
        )
        ax.set_xticks(x_positions)
        ax.set_xticklabels([f"t{t}" for t in threads])
        ax.grid(True, axis="y", linewidth=0.3)
        ax.legend(ncol=2, fontsize="small")

    axes[-1].set_xlabel("Threads")
    plt.tight_layout()
    out = os.path.join(OUT_DIR, out_name)
    plt.savefig(out, dpi=200)
    plt.close()


def _ordered_impls(impls: List[str]) -> List[str]:
    ordered: List[str] = []
    for name in ["kiri-rust", "kiri-swift", "rust", "swift", "axum", "vapor", "gin"]:
        if name in impls:
            ordered.append(name)
    for name in impls:
        if name not in ordered:
            ordered.append(name)
    return ordered


if __name__ == "__main__":
    main()
