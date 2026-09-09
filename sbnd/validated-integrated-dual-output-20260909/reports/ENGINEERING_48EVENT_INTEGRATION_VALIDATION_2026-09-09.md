# ENGINEERING 48-EVENT INTEGRATION VALIDATION — 2026-09-09

**WCT SHA:** `b2e3c6a9b440af9f440151d5e9c9aa1771194bd0`  
**larwirecell SHA:** `5c50b2dc31a8b8f07b4afe4e1987884e2f298901`  
**Input file:** SR=2728, run=1, subrun=2728, events 1–48  
**Raw H5:** `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/engineering-48evt/run/nugraph.h5`  
**Canonical H5:** `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/engineering-48evt/validation/integration-48evt-canonical.h5`  

---

## Config SHA256 (frozen)

| File | SHA256 |
|------|--------|
| `wcls-img-clus-integration-1evt.fcl` | `2859f5c9c5950bc1cec726fbbe4b9a5e5a3ec521f9cf2ae32cff9fdf5a12c0fe` |
| `wcls-img-clus-integration-1evt.jsonnet` | `617e556126550b435a092d26ee3d6da35799ce73bafb4bde66e850b547291dd4` |

---

## Raw H5 summary (48 events)

- Sample count: 48
- Total SPs: 228,461
- CTPC events: 48/48
- KNN_FALLBACK events: 0/48
- SPs/event: min=1060 max=12323 mean=4760
- Bundle provenance: mean=100.0%

## Output inventory

| File | Size |
|------|------|
| `reco_wirecell_integration_1evt.root` | 1,840,260,261 bytes |
| `mabc.zip` | 257,931,256 bytes |
| `mabc-pr.zip` | 1,906,003 bytes |
| `nugraph.h5` | 75,869,748 bytes |
| `trash-all-apa.tar.gz` | 88,477,973 bytes |
| `tf-default.root` | 7,355 bytes |

## Canonical H5

- Samples produced: 96 (expected 96)

## Schema comparison vs validated

| Field status | Count |
|-------------|-------|
| IDENTICAL_SCHEMA | 38 |
| MISSING | 0 |
| UNEXPECTED_NEW | 0 |

## NuGraph smoke

**Result:** NOT_RUN (ImportError)

## Validation log

```
  [PASS]  wcls-img-clus-integration-1evt.fcl: SHA256 correct  -- MATCH
  [PASS]  wcls-img-clus-integration-1evt.jsonnet: SHA256 correct  -- MATCH
  [PASS]  nugraph.h5 exists
  [PASS]  ≥1 raw event record
  [PASS]  =48 raw event records (48-event run)  -- got 48
  [PASS]  All 48 events have required raw H5 fields  -- 48/48
  [PASS]  features[:,1]==reco_segment_id for all 48 events  -- 48/48
  [PASS]  Bundle provenance ≥90% for all 48 events  -- 48/48 events at ≥90%
  [PASS]  Both APAs represented for all 48 events  -- 48/48
  [PASS]  Exact edge-set equality (sp_nexus_sp == sp/edge_label_index) for all 48 events  -- 48/48
  [PASS]  All 48 events have topology_source in {1,2}  -- 48/48
  [NOTE]  Topology breakdown: CTPC=48 KNN_FALLBACK=0
  [PASS]  RSE tuples are unique across 48 events  -- unique=48 total=48
  [PASS]  All events from run=1 subrun=2728  -- OK
  [PASS]  reco_wirecell_integration_1evt.root present
  [PASS]  mabc.zip present
  [PASS]  nugraph.h5 present
  [PASS]  mabc-pr.zip present
  [PASS]  Canonical adapter PASS (all events)  -- 48/48 events processed
  [PASS]  Canonical H5 has 96 APA samples (96 for 48 events)  -- got 96
  [PASS]  All canonical samples have valid RSE from SR=2728  -- 96/96
  [PASS]  All canonical samples have sp/features [N,2] float32  -- 96/96
  [PASS]  features[:,1]==reco_segment_id for all canonical samples  -- 96/96
  [PASS]  sp/reco_bundle_id present in all canonical samples  -- 96/96
  [PASS]  sp/apa absent (per-APA canonical) for all samples  -- 96/96
  [NOTE]  topology_source==1 (CTPC) in canonical: 96/96
  [PASS]  No required validated fields missing in integration canonical  -- missing: []
  [NOTE]  NuGraph smoke error: libhcoll.so.1: cannot open shared object file: No such file or directory
  [NOTE]  1-event reference: Nsp=6758 (APA0=4915, APA1=1843)
  [NOTE]  48-event aggregate: total_nsp=228461, mean/evt=4760
  [NOTE]  Overall bundle provenance: 100.0% populated (228461/228461)
```

---

## Final gate table

| Gate | Result |
| ---- | ------ |
| Integrated WCT loaded (b2e3c6a9) | ✓ |
| Integrated larwirecell loaded (5c50b2dc) | ✓ |
| Frozen config SHA256 verified | ✓ |
| 48 events completed (lar exit 0) | ✓ |
| 48 raw H5 records produced | ✓ |
| features[:,1]==reco_segment_id ALL events | ✓ |
| Bundle provenance ≥90% ALL events | ✓ |
| Exact edge-set equality ALL events | ✓ |
| CTPC topology events | 48/48 |
| KNN_FALLBACK events (engineering audit) | 0/48 |
| Traditional WCT outputs (mabc.zip etc.) | ✓ |
| ART ROOT produced | ✓ |
| Canonical adapter PASS | ✓ |
| 96 canonical APA samples | ✓ |
| Canonical schema compatible | ✓ |
| NuGraph smoke | NOT_RUN (ImportError) |

---

READY_TO_FREEZE_INTEGRATED_DUAL_OUTPUT_RELEASE