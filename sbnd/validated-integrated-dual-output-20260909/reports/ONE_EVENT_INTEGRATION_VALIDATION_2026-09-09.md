# ONE-EVENT INTEGRATION VALIDATION — 2026-09-09

**WCT SHA:** `b2e3c6a9b440af9f440151d5e9c9aa1771194bd0`  
**larwirecell SHA:** `5c50b2dc31a8b8f07b4afe4e1987884e2f298901`  
**Input file:** SR=2728, run=1, subrun=2728, event=1  
**Raw H5:** `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/one-event-test/run/nugraph.h5`  
**Canonical H5:** `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/one-event-test/validation/integration-1evt-canonical.h5`  

---

## FCL / jsonnet SHA256

| File | SHA256 |
|------|--------|
| `wcls-img-clus-integration-1evt.fcl` | `2859f5c9c5950bc1cec726fbbe4b9a5e5a3ec521f9cf2ae32cff9fdf5a12c0fe` |
| `wcls-img-clus-integration-1evt.jsonnet` | `617e556126550b435a092d26ee3d6da35799ce73bafb4bde66e850b547291dd4` |

---

## Raw H5 structure

- Sample count: 1
- Sample name: `1_2728_1__rec-lab-apa0-1`
- Nsp (total, both APAs): 6758
- APA values: [0, 1]
- topology_source: 1 (1=CTPC, 2=KNN_FALLBACK)

## Bundle / segment provenance

- bundle populated: 6758/6758 (100.0%)
- unique bundles: 17
- sentinel convention: bundle_id == -1 for unmatched SPs
- unique segments: 30

## Output inventory

| File | Size |
|------|------|
| `reco_wirecell_integration_1evt.root` | 45,331,537 bytes |
| `mabc.zip` | 7,867,162 bytes |
| `mabc-pr.zip` | 16,680 bytes |
| `nugraph.h5` | 2,249,864 bytes |
| `trash-all-apa.tar.gz` | 2,262,358 bytes |
| `tf-default.root` | 7,355 bytes |

## TensorSetLabeler placement

- **Instances**: 1 (single-instance, post-PR)
- **Architecture**: clus_all_apa (MABC) → pr_node (STM/TGM/FC taggers) → wclsTensorSetLabeler:clus_all_apa → TensorFileSink
- **label_blobs**: true (sim; truth labeling enabled)
- **bee_sets**: truth, sed, tagger, pf (all default sets)
- **hdf5_output**: true (writes nugraph.h5)
- **stamp_matching_bundle_id**: true (in pr_node, pr_all_apa MABC)
- **pf_metadata_key**: empty (single-instance, no downstream merger)
- **TensorSetMetadataAttacher**: NOT wired in graph (rse_from_ident=true used instead; H5 RSE correct via TensorSetLabeler art::Event visit)

## Canonical schema comparison

| Field status | Count |
|-------------|-------|
| IDENTICAL_SCHEMA | 38 |
| MISSING | 0 |
| UNEXPECTED_NEW | 0 |

## NuGraph smoke

**Result:** NOT_RUN (ImportError)

## Validation log

```
  [PASS]  nugraph.h5 exists
  [PASS]  ≥1 raw event record
  [PASS]  =1 raw event record (1-event run)  -- got 1
  [PASS]  All required raw H5 fields present
  [NOTE]  Extra fields not in required list: ['evt/num_nodes', 'evt/y', 'u/id', 'u/pos', 'u/x', 'u/y_instance', 'u/y_semantic', 'v/id', 'v/pos', 'v/x']
  [PASS]  RSE run correct  -- got 1
  [PASS]  RSE subrun correct  -- got 2728
  [PASS]  RSE event correct  -- got 1
  [PASS]  sp/features dtype float32  -- float32
  [PASS]  sp/features shape [N,6]  -- (6758, 6)
  [PASS]  sp/features[:,1].astype(int64) == sp/reco_segment_id (all SPs)  -- OK
  [PASS]  sp/reco_bundle_id dtype int64 (or compatible)
  [PASS]  sp/reco_bundle_id exists and non-empty
  [NOTE]  Bundle provenance fraction: 100.0% populated
  [PASS]  sp/reco_bundle_id ≠ sp/reco_segment_id (not degenerate)  -- identical by construction would be wrong
  [PASS]  sp/reco_segment_id present
  [PASS]  sp/apa values ⊆ {0,1}
  [PASS]  Both APAs represented (0 and 1)  -- got [np.int64(0), np.int64(1)]
  [PASS]  sp/face exists (from 6ead889)
  [PASS]  metadata/sp_topology_source exists
  [PASS]  topology_source = 1 (CTPC, not KNN_FALLBACK)  -- got 1 = CTPC
  [PASS]  sp_nexus_sp/edge_index: no negative indices  -- min=0
  [PASS]  sp_nexus_sp/edge_index: max index < Nsp  -- max=6757 Nsp=6758
  [NOTE]  sp_nexus_sp/edge_index: 19773 edges, range [0,6757]
  [PASS]  sp/edge_label_index: no negative indices  -- min=0
  [PASS]  sp/edge_label_index: max index < Nsp  -- max=6757 Nsp=6758
  [NOTE]  sp/edge_label_index: 19773 edges, range [0,6757]
  [NOTE]  sp_nexus_sp/edge_index: 19773 edges
  [NOTE]  sp/edge_label_index: 19773 edges
  [PASS]  sp/edge_label_index and sp_nexus_sp share same count (TSL contract)  -- nexus=19773 label=19773
  [NOTE]  u_nexus_sp/edge_index: 6730 edges, 980 plane nodes
  [PASS]  u_nexus_sp: plane indices valid
  [PASS]  u_nexus_sp: sp indices valid
  [NOTE]  v_nexus_sp/edge_index: 6623 edges, 1340 plane nodes
  [PASS]  v_nexus_sp: plane indices valid
  [PASS]  v_nexus_sp: sp indices valid
  [NOTE]  y_nexus_sp/edge_index: 6637 edges, 1126 plane nodes
  [PASS]  y_nexus_sp: plane indices valid
  [PASS]  y_nexus_sp: sp indices valid
  [PASS]  Canonical adapter PASS
  [PASS]  Canonical H5 has 2 APA samples  -- got 2
  [PASS]  1_2728_rec-lab-apa0-1: RSE correct  -- got 1/2728/1
  [PASS]  1_2728_rec-lab-apa0-1: sp/apa absent (per-APA canonical)
  [PASS]  1_2728_rec-lab-apa0-1: sp/features dtype float32
  [PASS]  1_2728_rec-lab-apa0-1: sp/features shape [N,2]
  [PASS]  1_2728_rec-lab-apa0-1: metadata/sp_topology_source == 1 (CTPC)
  [PASS]  1_2728_rec-lab-apa0-1: sp/reco_bundle_id present
  [PASS]  1_2728_rec-lab-apa0-1: sp/reco_segment_id present
  [PASS]  1_2728_rec-lab-apa0-1: features[:,1].astype(int64)==reco_segment_id
  [PASS]  1_2728_rec-lab-apa1-1: RSE correct  -- got 1/2728/1
  [PASS]  1_2728_rec-lab-apa1-1: sp/apa absent (per-APA canonical)
  [PASS]  1_2728_rec-lab-apa1-1: sp/features dtype float32
  [PASS]  1_2728_rec-lab-apa1-1: sp/features shape [N,2]
  [PASS]  1_2728_rec-lab-apa1-1: metadata/sp_topology_source == 1 (CTPC)
  [PASS]  1_2728_rec-lab-apa1-1: sp/reco_bundle_id present
  [PASS]  1_2728_rec-lab-apa1-1: sp/reco_segment_id present
  [PASS]  1_2728_rec-lab-apa1-1: features[:,1].astype(int64)==reco_segment_id
  [PASS]  No required validated fields missing in integration canonical  -- missing: []
  [NOTE]  NuGraph smoke error: libhcoll.so.1: cannot open shared object file: No such file or directory
```

---

## Final gate table

| Gate | Result |
| ---- | ------ |
| Integrated WCT actually loaded | ✓ (b2e3c6a9) |
| Integrated larwirecell actually loaded | ✓ (5c50b2dc) |
| Haiwang current reconstruction actually configured | ✓ (iso_endpoint removed; flash_by_gid default true; stamp_matching_bundle_id=true) |
| Event completed | ✓ lar exit 0 |
| RSE correct everywhere | ✓ |
| Traditional WCT outputs produced | ✓ mabc.zip mabc-pr.zip trash-all-apa.tar.gz |
| tracking-pr.root produced | ✗ NOT configured (not in pipeline_names — same as validated) |
| BDT score branches present | ✗ NOT configured (no tagger_output in pipeline_names — same as validated) |
| ART ROOT produced | ✓ |
| Raw nugraph.h5 produced | ✓ |
| Required raw NuGraph fields present | ✓ |
| Bundle provenance populated/valid | ✓ 100.0% populated |
| Segment provenance valid | ✓ |
| CTPC topology source = 1 | ✓ |
| Raw graph indices valid | ✓ (validated above) |
| Canonical adapter PASS | ✓ |
| 2 canonical APA samples produced | ✓ |
| Canonical schema compatible | ✓ |
| NuGraph smoke PASS/NOT_RUN | NOT_RUN (ImportError) |
| Ready for 48-event engineering validation | ✓ |

---

READY_FOR_48_EVENT_ENGINEERING_VALIDATION