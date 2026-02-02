import csv
import glob
import os
import re

REQ_RE = re.compile(r"Requests/sec:\s+([0-9.]+)")
LAT_RE = re.compile(r"Latency\s+([0-9.]+)(us|ms|s)")


def to_ms(value, unit):
    v = float(value)
    if unit == "us":
        return v / 1000.0
    if unit == "ms":
        return v
    if unit == "s":
        return v * 1000.0
    return None


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
pattern = os.path.join(out_dir, "wrk__*.txt")
rows = []

for path in sorted(glob.glob(pattern)):
    base = os.path.basename(path)
    # wrk__{impl}__{endpoint}__t{t}__c{c}__d{d}__run{n}.txt
    # split by "__"
    parts = base.replace(".txt", "").split("__")
    if len(parts) != 7:
        continue

    _, impl, endpoint, tpart, cpart, dpart, runpart = parts
    threads = int(tpart[1:])  # strip "t"
    conns = int(cpart[1:])  # strip "c"
    dur = int(dpart[1:])  # strip "d"
    run = int(runpart[3:])  # strip "run"

    text = open(path, "r", encoding="utf-8", errors="ignore").read()

    req = REQ_RE.search(text)
    lat = LAT_RE.search(text)

    if not req:
        # keep a row that indicates failure (optional)
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

    rps = float(req.group(1))
    lat_ms = to_ms(lat.group(1), lat.group(2)) if lat else None

    rows.append(
        {
            "file": path,
            "impl": impl,
            "endpoint": endpoint,
            "threads": threads,
            "connections": conns,
            "duration_s": dur,
            "run": run,
            "rps": rps,
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
    print(f"Wrote {out_csv} with {len(rows)} rows")
else:
    print(f"Wrote {out_csv} with 0 rows (no files matched {pattern})")
