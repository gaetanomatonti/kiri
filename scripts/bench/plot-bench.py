from __future__ import annotations

import os
from typing import List, cast

import matplotlib.pyplot as plt
import pandas as pd

OUT_DIR = "scripts/bench/.out"
CSV_PATH = os.path.join(OUT_DIR, "results.csv")


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

    plot_metric(
        agg=agg,
        metric_col="rps_median",
        ylabel="Requests/sec (median)",
        title_prefix="Throughput",
        out_name_prefix="throughput",
    )

    # Plot latency only if there is at least one non-NaN value
    lat_series = cast(pd.Series, agg["lat_median"])
    if lat_series.notna().any():  # any() is a bool, pyright-safe
        plot_metric(
            agg=agg,
            metric_col="lat_median",
            ylabel="Latency ms (median)",
            title_prefix="Latency",
            out_name_prefix="latency",
        )

    plot_ratio(agg)

    print("Saved plots into .out/ (png files).")


def plot_metric(
    *,
    agg: pd.DataFrame,
    metric_col: str,
    ylabel: str,
    title_prefix: str,
    out_name_prefix: str,
) -> None:
    endpoints = sorted(cast(List[str], agg["endpoint"].dropna().unique().tolist()))

    for endpoint in endpoints:
        sub_e = cast(pd.DataFrame, agg.loc[agg["endpoint"] == endpoint])
        threads_list = sorted(
            cast(List[int], sub_e["threads"].dropna().unique().tolist())
        )

        for threads in threads_list:
            sub_t = cast(pd.DataFrame, sub_e.loc[sub_e["threads"] == threads])

            # pivot_table is friendlier for typing than pivot
            pivot_tbl = cast(
                pd.DataFrame,
                sub_t.pivot_table(
                    index="connections",
                    columns="impl",
                    values=metric_col,
                    aggfunc="first",
                ).sort_index(),
            )

            ax = pivot_tbl.plot(marker="o")
            ax.set_xlabel("Connections")
            ax.set_ylabel(ylabel)
            ax.set_title(f"{title_prefix} — endpoint={endpoint} — threads={threads}")
            ax.grid(True, axis="y", linewidth=0.3)

            plt.tight_layout()
            out = os.path.join(
                OUT_DIR, f"{out_name_prefix}__{endpoint}__t{threads}.png"
            )
            plt.savefig(out, dpi=200)
            plt.close()


def plot_ratio(agg: pd.DataFrame) -> None:
    """
    Swift/Rust throughput ratio:
      ratio = swift_rps_median / rust_rps_median
    per endpoint and threads; x-axis is connections.
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
        print("Skipping ratio plots: need both 'swift' and 'rust' in impl.")
        return

    # Compute ratio column
    ratio_tbl["swift_over_rust"] = ratio_tbl["swift"] / ratio_tbl["rust"]

    endpoints = sorted(
        cast(List[str], ratio_tbl["endpoint"].dropna().unique().tolist())
    )
    for endpoint in endpoints:
        sub_e = cast(pd.DataFrame, ratio_tbl.loc[ratio_tbl["endpoint"] == endpoint])
        threads_list = sorted(
            cast(List[int], sub_e["threads"].dropna().unique().tolist())
        )

        for threads in threads_list:
            sub_t = cast(pd.DataFrame, sub_e.loc[sub_e["threads"] == threads])

            # sort_values expects a list or str; give list for pyright happiness
            sub_t = cast(pd.DataFrame, sub_t.sort_values(by=["connections"]))

            x = cast(pd.Series, sub_t["connections"])
            y = cast(pd.Series, sub_t["swift_over_rust"])

            plt.plot(x, y, marker="o")
            plt.xlabel("Connections")
            plt.ylabel("Swift/Rust throughput ratio")
            plt.title(f"Throughput ratio — endpoint={endpoint} — threads={threads}")
            plt.ylim(0, 1.05)
            plt.grid(True, axis="y", linewidth=0.3)

            plt.tight_layout()
            out = os.path.join(OUT_DIR, f"ratio__{endpoint}__t{threads}.png")
            plt.savefig(out, dpi=200)
            plt.close()


if __name__ == "__main__":
    main()
