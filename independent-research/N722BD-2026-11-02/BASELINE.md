# N722BD — Independent Open-Source Accident Reconstruction
**Registered baseline: November 2, 2026 (UTC). Version: 2.0, preliminary.**

**Case:** Learjet 60 N722BD / ICAO a9ab17; Palm Beach County, Florida, November 1, 2026; NTSB ERA27MA026. **Independent technical analysis, not an NTSB finding.** This public branch records predictions before the NTSB's public factual docket and final report. No assertion of official cause is made.

## Source-file fingerprints (SHA-256)
- Flightradar24 granular CSV, 78,107 rows: `8f7887a0c5d1efe47da78ce653721cfb5264f160f71debdeeda93e7bd2c771cd`.
- Unedited LiveATC Miami Center Sector 01 archive `KPBI1-ZMA01-Nov-01-2026-1730Z.mp3`, 1,779.6923 seconds: `d70ab2a51943d6261e350edf32b3840301167e7bba746248c711ad678f7e90cb`.
- Full November 2 technical Markdown report: `4307f20635ff27e20475b2775ad30c99eefffe249a240124d7d6a2bd07dc1690`.
- Reproducible release ZIP (report, Python analysis, derived figures, event ledger, manifest; no proprietary raw files): `bb992aad019b107f4adc15b9ad6ea1b40d25eb2168383ba4c20b1cc7c456123d`.
- PDF report: `32736b6cb08d29beb94764f804a5bd796d1d0b5e415c19a8b84e7b3a3f3177d1`.

Raw audio and FR24 data are not republished; third-party redistribution rights are not established. Source identifiers and derived measurements are furnished for independent verification.

## Direct reported-data observations (2026-11-01 UTC)
| Timestamp | Observation |
| --- | --- |
| 17:48:26.368 | First decoded vertical-rate report at or below −8,000 ft/min |
| 17:48:28.077 | First at or below −10,000 ft/min |
| 17:48:37.198 | First at or below −20,000 ft/min |
| 17:48:52.576 | First at or below −22,000 ft/min (not necessarily the meaning of a later spoken 22,000) |
| 17:49:03.607 | Decoded rate reaches reporting limit −32,640 ft/min |
| 17:49:04.389 | First altitude point below 22,000 ft (21,925 ft) |
| 17:49:22.955 | Last *changing* barometric-altitude report: 8,750 ft |
| 17:49:31.540 | Last changing latitude/longitude reported in CSV |
| 17:49:32.166 | Last reported horizontal ground-speed and track in CSV |

**Critical data limitation:** The −32,640-ft/min encoded field is not a true terminal descent-rate measurement. Subsequent repeated altitude of 8,750 ft is stale. CSV timestamp semantics have not been verified from raw receiver logs. Position integrity reportedly deteriorates near 17:49:25; coordinates are not accepted as exact ground truth.

An adjacent-sample finite difference of the changing barometric-altitude series around 17:49:15–22 gives a median downward rate near **47,900 ft/min**, conditional on altitude/timestamp validity. Quadratic fits of selected changing-altitude windows extrapolate to hypothetical ground at approximately **17:49:33.2–17:49:34.8 UTC**; this is a *model*, not direct evidence of the exact impact second.

The unedited LiveATC archive provisionally places the last crew transmission around **17:49:22 UTC**, assuming the first archive audio sample corresponds to 17:30:00 UTC. This absolute offset requires certification against FAA original radio time track. The approximately 10–11-second apparent post-radio interval is the principal unresolved synchronization question. A radio cutoff at impact and a radio cutoff before impact are competing interpretations.

## Registered, falsifiable hypotheses
**P1 — Actual downward velocity exceeded the ADS-B reporting limit.** Support: independent altitude-derived slopes. Strong conditional support, pending sensor/clock validation. Falsifier: corrected altitude/instrument data eliminate the inferred slopes.

**P2 — The aircraft remained airborne after final audible crew radio.** Support: changing later positions and conditional altitude extrapolation. Moderate support, *not* established. Falsifier: raw source timestamps demonstrate approximately ten seconds of report staleness, or certified FAA audio clock differs substantially.

**P3 — Major longitudinal-control departure preceded the extreme terminal descent.** Support: abrupt trajectory change and crew emergency. High confidence as a *loss-of-control state*, with initiating mechanism unresolved. Falsifier: authoritative data show another sequence.

**P4 — Horizontal-tail/pitch-control system contributed to the event.** Explicit test: establish whether horizontal stabilizer/elevator detached before the first Mayday, detached later under dynamic pressure, stayed attached but lost aerodynamic effectiveness, or was fully functional. Image failure to resolve a tailplane is **not** proof of separation. Remains a candidate mechanism, **not a finding**.

**P5 — Convective conditions contributed to initiation.** Evidence: crew icing/turbulence/precipitation reports and storm environment; test using time-corrected aircraft path, volumetric weather radar, air-data and wreckage diagnostics. Causal role unresolved.

## Public verification queue
FAA certified ATC audio/time track; FAA primary radar and ERAM sensor-level plots; raw receiver-timestamped ADS-B/Mode S data and message integrity; independent ground or satellite receptions; native dashcam video and camera calibration; TDWR/NEXRAD/GOES meteorology; tail assembly recovery, fracture surfaces, control trim, anti-ice system, CVR/FDR and aircraft avionics.

A later NTSB docket comparison shall label each registered prediction **confirmed / partially supported / contradicted / not addressed / unresolvable**, with pinpoint references and a new version. **Do not rewrite this original dated baseline.** Agreement is evidence of early inferential accuracy, not automatically evidence of unique discovery.

## Public source index
- NTSB: https://www.ntsb.gov/investigations/Pages/ERA27MA026.aspx
- FR24 original data and editorial: https://www.flightradar24.com/blog/flight-tracking-news/major-incident/learjet-60-crashes-near-west-palm-beach-florida/
- LiveATC Sector 01 archive: https://www.liveatc.net/archive.php?m=kpbi1_zma01
- Independent receiver analysis, separate report: https://map.flights/news/2434-crash-of-learjet-60-n722bd-near-west-palm-beach-on-11-1-2026-ads-b-data
- NTSB investigation duration background: https://www.ntsb.gov/tda/family/Pages/tda-aviation.aspx

**Scope note:** Hosted on an isolated public GitHub branch solely for independently verifiable publication timing, not integrated into or attributed to the repository's software project. The baseline is a joint human/AI-assisted analytical record; the first-principles stabilizer hypothesis and investigative framing originated from the human analyst.
