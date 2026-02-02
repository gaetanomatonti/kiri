from __future__ import annotations

import os
from typing import List, cast

import matplotlib.pyplot as plt
import pandas as pd

BASE_DIR = os.path.dirname(__file__)
OUT_DIR = os.path.join(BASE_DIR, ".out")
CSV_PATH = os.path.join(OUT_DIR, "results.csv")

COLOR_MAP = {
    "rust": "tab:blue",
    "swift": "tab:orange",
}

RATIO_COLOR = "tab:green"


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

    plot_ratio_all(agg)

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


def plot_ratio_all(agg: pd.DataFrame) -> None:
    """
    Swift/Rust throughput ratio:
      ratio = swift_rps_median / rust_rps_median
    per endpoint and connection; x-axis is threads.
    """
    ratio_tbl = cast(
        pd.DataFrame,
        agg.pivot_table(
            index=["endpoint", "threads", "connections"],
            columns="impl",
            values="rps_median",
            aggfunc="first",
        ).reset_index(),
    )

    cols = ratio_tbl.columns.astype(str).tolist()
    if "swift" not in cols or "rust" not in cols:
        print("Skipping ratio plot: need both 'swift' and 'rust' in impl.")
        return

    # Compute ratio column
    ratio_tbl["swift_over_rust"] = ratio_tbl["swift"] / ratio_tbl["rust"]

    endpoints = sorted(
        cast(List[str], ratio_tbl["endpoint"].dropna().unique().tolist())
    )
    if not endpoints:
        return

    pairs = sorted(
        cast(
            List[tuple],
            ratio_tbl[["endpoint", "connections"]]
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
            ratio_tbl.loc[
                (ratio_tbl["endpoint"] == endpoint)
                & (ratio_tbl["connections"] == connections)
            ],
        )
        sub_ec = cast(pd.DataFrame, sub_ec.sort_values(by=["threads"]))

        threads = cast(List[int], sub_ec["threads"].tolist())
        values = cast(List[float], sub_ec["swift_over_rust"].tolist())

        group_gap = 1.2
        x_positions = [i * group_gap for i in range(len(threads))]
        bar_width = 0.6

        ax.bar(
            x_positions,
            values,
            width=bar_width,
            color=RATIO_COLOR,
        )

        ax.set_ylabel("Swift/Rust throughput ratio")
        ax.set_title(
            f"Throughput ratio — endpoint={endpoint} — connections={connections}"
        )
        ax.set_ylim(0, 1.05)
        ax.set_xticks(x_positions)
        ax.set_xticklabels([f"t{t}" for t in threads])
        ax.grid(True, axis="y", linewidth=0.3)

    axes[-1].set_xlabel("Threads")
    plt.tight_layout()
    out = os.path.join(OUT_DIR, "ratio.png")
    plt.savefig(out, dpi=200)
    plt.close()


def _ordered_impls(impls: List[str]) -> List[str]:
    ordered: List[str] = []
    for name in ["rust", "swift"]:
        if name in impls:
            ordered.append(name)
    for name in impls:
        if name not in ordered:
            ordered.append(name)
    return ordered


if __name__ == "__main__":
    main()
