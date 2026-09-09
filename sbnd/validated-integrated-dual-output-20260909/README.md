# Validated Integrated SBND Dual-Output Release — 2026-09-09

Integrated dual-output Wire-Cell workflow using Haiwang's newer reconstruction
as the upstream base while preserving the NuGraph-specific reconstruction
provenance and canonical H5 contract.

---

## Code

### WireCell Toolkit (WCT)

| Item | Value |
|------|-------|
| Repository | `abhatfnal/wire-cell-toolkit` |
| Branch | `integration/haiwang-nugraph-dual-output-20260908` |
| SHA | `b2e3c6a9b440af9f440151d5e9c9aa1771194bd0` |
| Tag | `validated-dual-output-2026-09-09` |
| Haiwang integration base | `609dea85eff1a3e547aeefa29bb1b46871682da3` |
| Our provenance base (wct-doctest) | `086966835fa9ec158a747a31b64b97f2760c71a9` |

### larwirecell

| Item | Value |
|------|-------|
| Repository | `abhatfnal/larwirecell` |
| Branch | `integration/haiwang-nugraph-dual-output-20260908` |
| SHA | `5c50b2dc31a8b8f07b4afe4e1987884e2f298901` |
| Tag | `validated-dual-output-2026-09-09` |
| Haiwang integration base | `a02a1a4d84910032fd8c99cda496dd054c65a01b` |
| Our provenance base (sp/reco_bundle_id) | `83b905de9ec519eadb54adc3e1b3de407269b0b7` |
| Our provenance base (sp/face + APA) | `6ead889abe892a291e92a0bfaecb49a2f5590007` |

### What is NOT in this release

- **EventGraphIPC**: not included. No EventGraphIPC code was compiled into either
  library validated here.
- **TensorSetMetadataAttacher**: code exists in larwirecell (commit `6ead889`) but
  is NOT wired in the validated graph configuration. RSE is correctly stamped into
  the canonical H5 via TensorSetLabeler's `rse_from_ident=true` path.
- **Two-instance TensorSetLabeler**: capability exists in code but is NOT used.
  This release uses a single post-PR TensorSetLabeler instance.
- **tracking-pr.root / BDT output visitors**: not in `pipeline_names` and not
  validated. Absence is intentional and matches the upstream validated run (job
  184323).
- **DL-vertex H5**: not produced in this release.

---

## Configuration

### Config SHA256

| File | SHA256 |
|------|--------|
| `config/wcls-img-clus-integration-1evt.fcl` | `2859f5c9c5950bc1cec726fbbe4b9a5e5a3ec521f9cf2ae32cff9fdf5a12c0fe` |
| `config/wcls-img-clus-integration-1evt.jsonnet` | `617e556126550b435a092d26ee3d6da35799ce73bafb4bde66e850b547291dd4` |

### Why the FCL is named `*-1evt`

The FCL was created and SHA-frozen during the one-event integration test (PBS
184949). The same frozen FCL was used verbatim for the 48-event engineering run
(PBS 184959) with `lar -n 48`. The filename reflects its origin, not a
limitation: it processes however many events `lar -n N` requests.

### Key configuration properties

- **`iso_endpoint` removed**: the integrated WCT (`b2e3c6a9`) removed
  `iso_endpoint` from the `pr()` function signature in `clus.jsonnet`. The
  validated jsonnet at `wcls-img-clus-matching-xin.jsonnet` called
  `clus_maker.pr(..., iso_endpoint=true, ...)`. The integration-specific jsonnet
  in `config/` removes that parameter to match the new API.
- **`stamp_matching_bundle_id=true`**: enabled in `pr_node`. This stamps the
  coarse Q/L flash-bundle identifier into per-blob point clouds for NuGraph4
  provenance.
- **Single post-PR TensorSetLabeler**: graph architecture is
  `clus_all_apa (MABC) → pr_node (STM/TGM/FC taggers) → wclsTensorSetLabeler:clus_all_apa → TensorFileSink`.
- **`rse_from_ident=true`**: TensorSetLabeler uses this path for RSE stamping.
  H5 RSE is correct because TensorSetLabeler visits the art::Event directly.
- **SCE path override**: `tmp-sce-override-integration/` patches the integration
  WCT's `clus.jsonnet` to replace the CVMFS SCE path with the Flare filesystem
  path. The WIRECELL_PATH ordering ensures this shadow takes precedence.
- **`flash_by_gid=true`**, **`save_in_scope=false`**, **`mcs_enable=false`**:
  integration WCT defaults, not changed.

---

## Validation summary

### One-event test (PBS 184949)

- **Input**: run=1 / subrun=2728 / event=1 (SR=2728 source file)
- **lar exit**: 0
- **RSE correct**: run=1 subrun=2728 event=1
- **CTPC topology**: yes (topology_source=1)
- **Total SPs**: 6758 (APA0=4915, APA1=1843)
- **Bundle provenance**: 6758/6758 = 100.0%, 17 unique bundles
- **Segments**: 30 unique, no sentinels
- **features[:,1] == reco_segment_id**: all SPs
- **Canonical adapter**: 2 APA samples produced
- **Canonical schema**: 38 IDENTICAL / 0 MISSING / 0 UNEXPECTED vs validated job 184323
- **NuGraph smoke**: NOT_RUN (`libhcoll.so.1` unavailable outside SLF7 container)

Traditional WCT outputs produced:

| File | Size |
|------|------|
| `reco_wirecell_integration_1evt.root` | 45 MB |
| `mabc.zip` | 7.5 MB |
| `mabc-pr.zip` | 16 KB |
| `nugraph.h5` | 2.1 MB |
| `trash-all-apa.tar.gz` | 2.2 MB |
| `tf-default.root` | 7.4 KB |

Full report: `reports/ONE_EVENT_INTEGRATION_VALIDATION_2026-09-09.md`

---

### 48-event persistent engineering test (PBS 184959)

- **Run command**: `lar --nskip 0 -n 48` — ONE persistent process
- **lar exit**: 0
- **Events**: 48 raw H5 records, all from run=1 subrun=2728
- **RSE unique**: 48/48
- **CTPC topology**: 48/48 (0 KNN_FALLBACK)
- **Total SPs**: 228,461 (min=1060 max=12323 mean=4760 per event)
- **Bundle provenance**: 228,461/228,461 = 100.0%, zero sentinels
- **features[:,1] == reco_segment_id**: 48/48 events, all SPs
- **Exact edge-set equality** (`sp_nexus_sp == sp/edge_label_index`): 48/48 events
- **Both APAs represented**: 48/48 events
- **Canonical adapter**: 96 APA samples produced (48 events × 2 APAs)
- **Canonical schema**: 38 IDENTICAL / 0 MISSING / 0 UNEXPECTED vs validated
- **NuGraph smoke**: NOT_RUN (`libhcoll.so.1` unavailable outside SLF7 container;
  this is a runtime environment dependency, not an H5/schema failure)

Traditional WCT outputs produced:

| File | Size |
|------|------|
| `reco_wirecell_integration_1evt.root` | 1.8 GB |
| `mabc.zip` | 246 MB |
| `mabc-pr.zip` | 1.9 MB |
| `nugraph.h5` | 73 MB |
| `trash-all-apa.tar.gz` | 85 MB |
| `tf-default.root` | 8.0 KB |

Generated data files are NOT committed to this repository. They reside at:

```
/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/engineering-48evt/run/
```

Full report: `reports/ENGINEERING_48EVENT_INTEGRATION_VALIDATION_2026-09-09.md`

---

## Scripts

All scripts are in `scripts/`. Actual filenames on disk are preserved (some
differ from the suggested release names in the task spec):

| Script | Purpose |
|--------|---------|
| `pbs_one_event_integration_2026_09_09.pbs` | PBS wrapper for 1-event test (job 184949) |
| `run_one_event_integration.sh` | Container-side script for 1-event test |
| `validate_one_event_integration.py` | Python validator for 1-event H5/canonical |
| `pbs_48evt_integration_2026_09_09.pbs` | PBS wrapper for 48-event test (job 184959) |
| `run_48evt_integration.sh` | Container-side script for 48-event test |
| `validate_48evt_integration.py` | Python validator for 48-event H5/canonical |

### Validator driver correction (48-event)

The first attempt at 48-event canonical generation used
`adapt_tsl_to_canonical(..., source_index=i)` in a loop, expecting `source_index`
to select which event to read from the multi-event H5 file. This was incorrect:
`source_index` is an `EventIdentity` field used for BLAKE2b split assignment, not
for selecting the source event within the H5. When `sample_name=None` (the
default), `read_tsl_event` always reads the first HDF5 insertion-order key
regardless of `source_index`.

The corrected `validate_48evt_integration.py` (committed here) drives the adapter
layer directly:

```python
with StreamingH5Writer(CANONICAL_H5) as writer:
    for i, skey in enumerate(dataset_keys):
        arrays, _ = read_tsl_event(RAW_H5, sample_name=skey)
        # build per-APA graphs
        graph0 = build_apa_graph(arrays, 0, run, subrun, event, topology_gate=False)
        graph1 = build_apa_graph(arrays, 1, run, subrun, event, topology_gate=False)
        identity = EventIdentity(campaign_id=CAMPAIGN_ID, ...)
        writer.append_event(identity, graph0, graph1)
```

This is a **validator/driver correction** — the production `adapt_tsl.py`
algorithm (`build_apa_graph`, `StreamingH5Writer`, `EventIdentity`) is correct.
Only the driver loop in the validation script was wrong in the first attempt.

---

## Site-specific paths

The scripts reference absolute Sophia/Eagle paths. These are intentional
provenance documentation:

- Input source file: `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/reference/extracted/02_workflow_test/test/test/prodgenie_bnb_nu_cosmic_sbnd_GenieGen-*`
- Integration build: `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/`
- Container images: `/lus/eagle/projects/neutrinoGPU/larsoft_hpc/images/`
- SIF: `/lus/grand/projects/neutrinoGPU/software/containers/slf7.sif`
- Conda env: `/lus/eagle/projects/neutrinoGPU/abhat/conda/envs/nugraph-a-sophia/`

To reproduce on a different site, update these paths to the local equivalents.
The repository-relative files (config/, scripts/) are site-independent.

---

## Relation to Sep-8 checkpoint

This branch was created from
`checkpoint/validated-dual-output-2026-09-08` at
`b949ae9ee043000dcdc71cd4fc949528ed4ce793`. The Sep-8 checkpoint documents the
pre-integration validated dual-output state (job 184323, WCT `bc7f4af9`,
larwirecell `9295e2a`). This release documents the result of integrating Haiwang's
reconstruction updates into that baseline. The Sep-8 checkpoint is immutable and
was not modified.
