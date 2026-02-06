import csv
import glob
import json
import os

FIELDNAMES = [
    "file",
    "impl",
    "endpoint",
    "threads",
    "connections",
    "duration_s",
    "run",
    "rps",
    "latency_ms",
    "ok",
]

base_dir = os.path.dirname(__file__)
out_dir = os.path.join(base_dir, ".out")
pattern = os.path.join(out_dir, "oha__*.json")
rows = []

for path in sorted(glob.glob(pattern)):
    base = os.path.basename(path)
    # oha__{impl}__{endpoint}__t{t}__c{c}__d{d}__run{n}.json
    # split by "__"
    parts = base.replace(".json", "").split("__")
    if len(parts) != 7:
        continue

    _, impl, endpoint, tpart, cpart, dpart, runpart = parts
    threads = int(tpart[1:])  # strip "t"
    conns = int(cpart[1:])  # strip "c"
    dur = int(dpart[1:])  # strip "d"
    run = int(runpart[3:])  # strip "run"

    try:
        payload = json.load(open(path, "r", encoding="utf-8"))
    except Exception:
        payload = {}

    summary = payload.get("summary", {}) if isinstance(payload, dict) else {}

    rps = summary.get("requestsPerSec")
    if rps is None:
        rps = summary.get("requests_per_sec")
    if rps is None and isinstance(payload, dict):
        rps = payload.get("requestsPerSec")

    # oha average latency values are in seconds in JSON output.
    lat_s = summary.get("average")
    if lat_s is None:
        lat_s = summary.get("avg")
    lat_ms = float(lat_s) * 1000.0 if lat_s is not None else None

    if rps is None:
        rows.append(
            {
                "file": path,
                "impl": impl,
                "endpoint": endpoint,
                "threads": threads,
                "connections": conns,
                "duration_s": dur,
                "run": run,
                "rps": "",
                "latency_ms": "",
                "ok": "0",
            }
        )
        continue

    rows.append(
        {
            "file": path,
            "impl": impl,
            "endpoint": endpoint,
            "threads": threads,
            "connections": conns,
            "duration_s": dur,
            "run": run,
            "rps": float(rps),
            "latency_ms": lat_ms if lat_ms is not None else "",
            "ok": "1",
        }
    )

out_csv = os.path.join(out_dir, "results.csv")
os.makedirs(out_dir, exist_ok=True)
with open(out_csv, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=FIELDNAMES)
    w.writeheader()
    w.writerows(rows)

if rows:
    print(f"Wrote {out_csv} with {len(rows)} rows from oha output")
else:
    print(f"Wrote {out_csv} with 0 rows (no files matched {pattern})")
