#!/usr/bin/env python3
"""N722BD minimal terminal ADS-B reconstruction. 2026-11-02.
Input: original provider CSV, SHA256 verified in BASELINE.md.
Provider timestamps are NOT presumed to equal raw RF receiver timestamps.
"""
import sys, hashlib
from pathlib import Path
import pandas as pd
import numpy as np

path=Path(sys.argv[1])
h=hashlib.sha256(path.read_bytes()).hexdigest()
expected="8f7887a0c5d1efe47da78ce653721cfb5264f160f71debdeeda93e7bd2c771cd"
assert h==expected, f"Input CSV hash differs: {h}"
d=pd.read_csv(path)
d.Timestamp=pd.to_datetime(d.Timestamp,utc=True)
d=d.sort_values("Timestamp")
d=d[(d.Timestamp>="2026-11-01 17:48:00Z") & (d.Timestamp<="2026-11-01 17:49:34Z")]
for rate in [-8000,-10000,-20000,-22000,-32640]:
    rows=d[d.vertical_rate<=rate]
    print(f"First decoded vertical-rate <= {rate}: {rows.Timestamp.iloc[0]}")
q=d[d.altitude.notna()]
print("First decoded altitude below 22000:",q[q.altitude<22000].Timestamp.iloc[0])
print("First 8750 ft stale-altitude plateau:",q[q.altitude==8750].Timestamp.iloc[0])
z=d[d.latitude.notna()&d.longitude.notna()].tail(1)
print("Final changed position:",z[["Timestamp","latitude","longitude"]].to_string(index=False))
v=d[d.ground_speed.notna()].tail(1)
print("Final speed/track:",v[["Timestamp","ground_speed","track"]].to_string(index=False))
# The vertical-rate field saturates; compare observed altitude increments instead.
late=q[(q.Timestamp>="2026-11-01 17:49:15Z")&(q.Timestamp<="2026-11-01 17:49:22.955011Z")].copy()
dt=late.Timestamp.diff().dt.total_seconds()
inferred=-60*late.altitude.diff()/dt
print("Median derived downward ft/min:",inferred.median())
# Purely conditional extrapolations (quadratic fit; ground-reference 20 ft MSL).
t_ref=pd.Timestamp("2026-11-01 17:49:00Z")
for start in [10,13,15,17,18]:
    w=q[(q.Timestamp>=pd.Timestamp(f"2026-11-01 17:49:{start:02d}Z"))&
        (q.Timestamp<=pd.Timestamp("2026-11-01 17:49:22.955011Z"))]
    x=(w.Timestamp-t_ref).dt.total_seconds().to_numpy()
    a,b,c=np.polyfit(x,w.altitude.to_numpy(),2)
    roots=np.roots([a,b,c-20])
    roots=[float(y.real) for y in roots if abs(y.imag)<1e-5 and 22<y.real<60]
    print(f"Conditional t_impact for window {start}:49 to 22: {min(roots) if roots else 'none'} seconds after 17:49:00")
