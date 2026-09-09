# Integration Branch Build Report — 2026-09-08

**Author:** abhat@uchicago.edu  
**Date:** 2026-09-08  
**Purpose:** Controlled cherry-pick of our NuGraph4 provenance commits onto Haiwang's integration base. Result (updated 2026-09-09): WCT cherry-pick complete with manually resolved conflicts; LWC cherry-pick pending.

---

## Phase 0 — Preflight ✅ COMPLETE

| Item | Result |
|------|--------|
| WCT validated base (ours) | `bc7f4af9` at `wct-ap-yuhw` [pr/nugraph4-wct-integration] |
| WCT integration base (Haiwang) | `609dea85eff1a3e547aeefa29bb1b46871682da3` |
| WCT common ancestor | `13ed51676db361a0c31b216700e77d8915ece399` |
| LWC validated base (ours) | `9295e2a` at `larwirecell-dev` [dev-v10_14_02_02] |
| LWC integration base (Haiwang) | `a02a1a4d84910032fd8c99cda496dd054c65a01b` |
| LWC common ancestor | `3b07b85e6b5e94f5cc113371f9c6f3719ad69ac7` |
| Haiwang SHAs absent from validated worktrees | CONFIRMED (not in wct-ap-yuhw or larwirecell-dev) |
| Haiwang SHAs present in scratchpad clones | CONFIRMED (haiwang-wct, haiwang-larwirecell) |
| Integration directory | `integration-2026-09-08/` — created empty |

---

## Phase 1 — WCT Integration Worktree ✅ COMPLETE (with manually resolved conflicts)

### Steps completed

1. Added `haiwang-local` remote to `wct-ap-yuhw` pointing to scratchpad clone  
   `$SCRATCH/haiwang-wct`
2. Fetched `haiwang-local` — brought in `haiwang-local/ap-2026-09-05+yuhw`
3. Verified `609dea85` object type: `commit` ✅
4. Created worktree + branch:
   ```
   git -C wct-ap-yuhw worktree add \
     -b integration/haiwang-nugraph-dual-output-20260908 \
     integration-2026-09-08/wct \
     609dea85eff1a3e547aeefa29bb1b46871682da3
   ```
5. Verified worktree HEAD = `609dea85` ✅, status clean ✅

### Pre-cherry-pick record (as required)

```
HEAD:   609dea85eff1a3e547aeefa29bb1b46871682da3
STATUS: (empty — clean working tree)
LOG:
609dea85 cfg/sbnd: restore pre_mabc forwarding and the clus_pr RSE key, both dropped by the merge
700226d5 merge ap-yuhw (our SBND features) into ap-2026-09-05 (94590129)
94590129 cfg,test/sbnd: flip the doc-99 flash knobs ON for SBND production (T_cluster 50.7% -> 100%)
```

### Cherry-pick attempted

```
git cherry-pick 086966835fa9ec158a747a31b64b97f2760c71a9
```

### Result: CONFLICT — two files

```
Auto-merging cfg/pgrapher/experiment/sbnd/clus.jsonnet
CONFLICT (content): Merge conflict in cfg/pgrapher/experiment/sbnd/clus.jsonnet
Auto-merging clus/inc/WireCellClus/MultiAlgBlobClustering.h     ← MERGED CLEANLY
Auto-merging clus/src/MultiAlgBlobClustering.cxx                ← MERGED CLEANLY
Auto-merging clus/src/clustering_switch_scope.cxx
CONFLICT (content): Merge conflict in clus/src/clustering_switch_scope.cxx
error: could not apply 08696683... clus: preserve matching bundle provenance for NuGraph4
```

Cherry-pick was aborted initially (`git cherry-pick --abort`). Both conflicts were manually resolved (see Conflict Diagnostic below), files staged, and `git cherry-pick --continue` completed successfully.

**Final WCT HEAD:** `b2e3c6a9b440af9f440151d5e9c9aa1771194bd0`  
**Commit message:** `clus: preserve matching bundle provenance for NuGraph4`  
**Files changed:** 5 files, 366 insertions(+), 0 deletions(-)

---

## Conflict Diagnostic

Both conflicts are **context-line conflicts caused by Haiwang's branch adding new entries to arrays and parameter lists that our commit also touches**. There is NO semantic incompatibility — the code logic in `08696683` is fully valid against `609dea85`. Resolution is deterministic in both cases.

### Conflict 1: `clus/src/clustering_switch_scope.cxx` (line 99)

**What `08696683` did (from `13ed516` merge-base):**  
Added `"matching_bundle_id"` as the last entry of `carry_anames[]`:
```cpp
// 13ed516 version (3 entries):
static const char* const carry_anames[] = {
    "real_cluster_id", "real_cluster_main",      // flash merge (doc 38)
    "assoc_cluster_id", "assoc_cluster_main",    // isolated grouping (doc 52)
    "real_cluster_was_main",                     // pre-merge main (doc pr/20 I)
};
// 08696683 added:
+   "matching_bundle_id",                        // coarse bundle provenance (MABC stamp)
```

**What Haiwang's `609dea85` independently added:**  
A fourth entry `"nu_band_veto_role"` (iso-band refusal, doc pr/66):
```cpp
// 609dea85 version (4 entries — adds nu_band_veto_role):
static const char* const carry_anames[] = {
    "real_cluster_id", "real_cluster_main",      // flash merge (doc 38)
    "assoc_cluster_id", "assoc_cluster_main",    // isolated grouping (doc 52)
    "real_cluster_was_main",                     // pre-merge main (doc pr/20 I)
    "nu_band_veto_role",                         // iso-band refusal (doc pr/66)
};
```

**Git's confusion:** Our patch context ends with `"real_cluster_was_main"` as the terminal entry followed by `};`. Haiwang's version has `"nu_band_veto_role"` in that position. Git cannot tell whether to insert before or after `"nu_band_veto_role"`.

**Deterministic resolution:** The merged array must have 5 entries:
```cpp
static const char* const carry_anames[] = {
    "real_cluster_id", "real_cluster_main",      // flash merge (doc 38)
    "assoc_cluster_id", "assoc_cluster_main",    // isolated grouping (doc 52)
    "real_cluster_was_main",                     // pre-merge main (doc pr/20 I)
    "nu_band_veto_role",                         // iso-band refusal (doc pr/66)
    "matching_bundle_id",                        // coarse bundle provenance (MABC stamp)
};
```
(`"matching_bundle_id"` appended after `"nu_band_veto_role"` — ordering is irrelevant since carry_anames is iterated with `has_pcarray` guard.)

---

### Conflict 2: `cfg/pgrapher/experiment/sbnd/clus.jsonnet` (multiple locations)

**What `08696683` did (from `13ed516` merge-base):**  
Added `stamp_matching_bundle_id=false` parameter to two function signatures that previously ended with `dl_vtx_cut=null`:

- **Inner function `clus_pr` signature** (was line 1073 in 13ed516):  
  `dl_vtx_cut=null) = {` → `dl_vtx_cut=null, stamp_matching_bundle_id=false) = {`

- **Outer function signature** (was line 1951 in 13ed516):  
  `dl_vtx_cut=null)::` → `dl_vtx_cut=null, stamp_matching_bundle_id=false)::`

- **Forwarding call** (was line 2041 in 13ed516):  
  Added `stamp_matching_bundle_id=stamp_matching_bundle_id,` to the inner call.

- **In the MABC node config** (was line 1746 in 13ed516):  
  Added `[if stamp_matching_bundle_id then 'stamp_matching_bundle_id']: true,`

**What Haiwang's `609dea85` independently added after `dl_vtx_cut`:**  
Two new parameters: `fast_xgb_forest=false,` and `tcn_knobs={})::`. In 609dea85, the inner function signature now ends at line 1925 with:
```jsonnet
              fast_xgb_forest=false,
       // doc 77 round 2: ...
       tcn_knobs={}):: {
```

**Git's confusion:** Our patch context expects `dl_vtx_cut=null) = {` (or `dl_vtx_cut=null)::`) as the terminal line. In 609dea85, those same positions now have `fast_xgb_forest=false,` and `tcn_knobs={})`.

**Deterministic resolution for each location:**

1. **Inner `clus_pr` signature** (around line 1920 in 609dea85): Add `stamp_matching_bundle_id=false,` before `fast_xgb_forest=false,`:
   ```jsonnet
               dl_vtx_cut=null,
               stamp_matching_bundle_id=false,
               // fast_xgb_forest: ...
               fast_xgb_forest=false,
   ```

2. **Outer function signature** (around line 1957 in 609dea85): Add `stamp_matching_bundle_id=false,` in parameter list (anywhere before `tcn_knobs={})`).

3. **Outer → inner forwarding call**: Add `stamp_matching_bundle_id=stamp_matching_bundle_id,` alongside `fast_xgb_forest=fast_xgb_forest,` (around line 2412 in 609dea85).

4. **MABC node config**: The `[if stamp_matching_bundle_id then 'stamp_matching_bundle_id']: true,` line was in the MABC node's pipeline config. This location needs to be found in 609dea85 and the line inserted. In 609dea85 `pipeline: wc.tns(cm_pipeline),` should still be nearby; insert after it the same conditional key expression.

---

### Auto-merged files (no conflicts)

Both of these merged cleanly without conflict — Haiwang's branch did not touch these sections:

| File | What merged cleanly |
|------|---------------------|
| `clus/inc/WireCellClus/MultiAlgBlobClustering.h` | New `stamp_matching_bundle_id()` method declaration + `m_stamp_matching_bundle_id` bool member |
| `clus/src/MultiAlgBlobClustering.cxx` | New `stamp_matching_bundle_id()` implementation (~35 lines) + `configure()` getter + `operator()` call before PR loop |

These are the core C++ implementation changes. Only the config wire-up (jsonnet) and the carry propagation (`clustering_switch_scope.cxx`) need manual merge.

---

## Phase 2–6 Status

Phase 1 complete. Phases 2–6 not yet started.

---

## Phase 1 — Post-Cherry-Pick Verification ✅ PASSED

| Check | Result |
|-------|--------|
| WCT HEAD SHA | `b2e3c6a9b440af9f440151d5e9c9aa1771194bd0` |
| Diff 609dea85..HEAD | 5 files, 366 insertions — **only** `08696683` functionality |
| `matching_bundle_id` in stamping implementation | `MultiAlgBlobClustering.cxx` ×13 occurrences ✓ |
| `matching_bundle_id` in configuration/member declaration | `MultiAlgBlobClustering.h` ×5 occurrences ✓ |
| `matching_bundle_id` in `carry_anames` | `clustering_switch_scope.cxx` line 100 ✓ |
| `stamp_matching_bundle_id=false,` parameter | `clus.jsonnet` line 1922 (before `fast_xgb_forest`) ✓ |
| `[if stamp_matching_bundle_id ...]` MABC node key | `clus.jsonnet` line 2791 ✓ |
| Haiwang's `nu_band_veto_role` preserved | `clustering_switch_scope.cxx` line 99 ✓ |
| Haiwang's `fast_xgb_forest=false,` preserved | `clus.jsonnet` line 1928 ✓ |
| Haiwang's `tcn_knobs={}` preserved | `clus.jsonnet` line 1933 ✓ |
| Haiwang's `reset_for_new_event()` intact | `TrackFitting.h:343`, `.cxx:291`, `TaggerCheckSTM.cxx:487`, `TaggerCheckNeutrino.cxx:1638` ✓ |
| Our `m_grouping=nullptr` clear_segments reset NOT present | Absent from `MultiAlgBlobClustering.cxx` ✓ |
| Worktree clean | `git status --short` empty ✓ |

No unexpected additional diff detected. All changes are exactly the `08696683` functionality adapted to Haiwang's evolved context.

---

## Worktree Summary

| Repo | Path | Branch | HEAD | State |
|------|------|--------|------|-------|
| wire-cell-toolkit | `wct-ap-yuhw/` | `pr/nugraph4-wct-integration` | `bc7f4af9` | unchanged (validated) |
| wire-cell-toolkit | `integration-2026-09-08/wct/` | `integration/haiwang-nugraph-dual-output-20260908` | `b2e3c6a9` | CLEAN — cherry-pick 08696683 applied ✓ |
| larwirecell | `larwirecell-dev/` | `dev-v10_14_02_02` | `9295e2a` | unchanged (validated) |
| larwirecell | `integration-2026-09-08/larwirecell/` | `integration/haiwang-nugraph-dual-output-20260908` | `5c50b2dc` | CLEAN — cherry-picks 83b905d + 6ead889 applied ✓ |

---

## Phase 2 — larwirecell Integration

**Base:** `a02a1a4d84910032fd8c99cda496dd054c65a01b` (Haiwang's `dev-v10_14_02_02`)  
**Branch:** `integration/haiwang-nugraph-dual-output-20260908`  
**Cherry-picks applied (in order):**
1. `83b905d` → `8442ae5498fcbb4db251e29e4bc09391a3779af8` (add `sp/reco_bundle_id`, `sp/reco_segment_id`)
2. `6ead889` → `5c50b2dc31a8b8f07b4afe4e1987884e2f298901` (add `sp/apa`, `sp/face`, `{u,v,y}/apa`, `{u,v,y}/face`, `metadata/sp_topology_source`)

**Excluded:** `9295e2a` (EventGraphIPC — optional for offline H5 pipeline, not required)

**Diff summary:** 1 file changed (`larwirecell/aiml/TensorSetLabeler.cxx`), 58 insertions(+), 1 deletion(-)

---

### Phase 2 — Source Verification ✅ PASSED

| # | Check | Detail | Result |
|---|-------|--------|--------|
| 1 | Base SHA | `a02a1a4d84910032fd8c99cda496dd054c65a01b` (Haiwang `dev-v10_14_02_02`) | ✓ |
| 2 | `83b905d` cherry-pick | Applied cleanly, no conflicts → `8442ae5498fcbb4db251e29e4bc09391a3779af8` | ✓ |
| 3 | `6ead889` cherry-pick | Applied cleanly, no conflicts → `5c50b2dc31a8b8f07b4afe4e1987884e2f298901` | ✓ |
| 4 | Conflicts? | None in either cherry-pick | ✓ (none) |
| 5 | Resulting HEAD SHA | `5c50b2dc31a8b8f07b4afe4e1987884e2f298901` | ✓ |
| 6 | Two-instance TSL preserved? | `label_blobs=false` path intact at TSL:1051; `bee_sets`, `pf_metadata_key` present; both TSL code paths untouched | ✓ |
| 7 | TensorSetMetadataAttacher preserved? | `larwirecell/Components/TensorSetMetadataAttacher.h/.cxx` present and unmodified; `wclsTensorSetMetadataAttacher` factory registered | ✓ |
| 8 | `sp/reco_bundle_id` present? | `addI("sp/reco_bundle_id", std::move(sp_bundle_id), {Nsp})` at TSL:1668; reads `matching_bundle_id` from perblob PC (lines 1351–1362); sentinel `kNoBundleId = -1` at line 1354 | ✓ |
| 9 | `sp/reco_segment_id` present? | `addI("sp/reco_segment_id", std::move(sp_segment_id), {Nsp})` at TSL:1669; `sp_segment_id.push_back(reco_clid)` at 1397; `reco_clid = cluster_scalar["ident"]` at 1344; invariant documented at 1387 | ✓ |
| 10 | APA/face fields present? | `addI("sp/apa",...)` TSL:1673; `addI("sp/face",...)` TSL:1674; `addI(p+"/apa",...)` TSL:1730,1739; `addI(p+"/face",...)` TSL:1731,1740 — covers `u/v/y/apa` and `u/v/y/face` | ✓ |
| 11 | `metadata/sp_topology_source` present? | `addI("metadata/sp_topology_source", {sp_topology_source}, {})` at TSL:1649; value set at TSL:1492: `(tried_ctpc && ctpc_ok) ? 1LL : 2LL` (1=CTPC, 2=KNN_FALLBACK) | ✓ |
| 12 | `sp/features [N,6]` unchanged? | `addF("sp/features", std::move(sp_feat), {(unsigned long long)Nsp, 6})` at TSL:1653; col 1 = `reco_clid` at 1389; `features[:,1] == reco_clid == reco_segment_id` invariant at 1387; `sp/reco_bundle_id ≠ sp/features[:,1]` (distinct sources) | ✓ |
| 13 | CTPC graph logic unchanged? | `bbset` created at TSL:1424; `ctpc_ok` gate at 1425; `find_graph("ctpc")` at 1459; KNN fallback lambda at 1426, activated at 1481–1484; `sp/edge_label_index` at 1688; `sp_nexus_sp/edge_index` at 1696; truth edge label `ey.push_back(labelable && t1 == t2 ? 1 : 0)` at 1684 — all intact | ✓ |
| 14 | EventGraphIPC absent? | No `EventGraphIPC.cxx` or `EventGraphIPC.h` in worktree; `9295e2a` deliberately excluded | ✓ |
| 15 | Working tree clean? | `git status --short` empty after both cherry-picks | ✓ |

All 15 checks passed. No unexpected files changed. Only `TensorSetLabeler.cxx` modified (58 insertions, 1 deletion).

---

READY_FOR_COMBINED_BUILD_PHASE

---

## Combined Build Phase — Environment Discovery (2026-09-09)

**PBS job:** `184894.sophia-pbs-01.lab.alcf.anl.gov`  
**PBS script:** `haiwang-current/pbs_integration_build_2026_09_09.pbs`  
**Container script:** `haiwang-current/run_integration_build.sh`  
**Log:** `integration-2026-09-08/build/logs/container_integration_build.log`  
**Status:** SUBMITTED — container will append build results below when complete

### Environment (Phase 1 discovery — from login node)

| Item | Value |
|------|-------|
| Sophia host | Sophia HPC (ALCF) |
| Container image | `/lus/grand/projects/neutrinoGPU/software/containers/slf7.sif` (SLF7/EL7) |
| larsoft squashfs | `/lus/eagle/projects/neutrinoGPU/larsoft_hpc/images/larsoft-v10_14_02.squashfs` |
| sbnd delta squashfs | `/lus/eagle/projects/neutrinoGPU/larsoft_hpc/images/sbnd-v10_14_02_04_delta.squashfs` |
| Environment file | `/lus/eagle/projects/neutrinoGPU/larsoft_hpc/envs/sbndcode-v10_14_02_04.env` |
| sbndcode version | v10_14_02_04 |
| larsoft version | v10_14_02 (v10_14_02_02 MRB base) |
| Compiler | GCC 12.1.0 (`Linux64bit+3.10-2.17`) |
| Validated WCT opt | `haiwang-current/opt/` (read-only reference for spdlog/bzip2 deps) |
| Integration WCT install | `integration-2026-09-08/build/opt/` (isolated) |
| larwirecell cmake build | `integration-2026-09-08/build/mrb-build/` |
| larwirecell install | `integration-2026-09-08/build/lwc-install/` |
| WCT build system | waf (`python3 wcb`) |
| larwirecell build system | cmake (MRB-style, squashfs cmake v3.27.4) |
| `WIRECELL_PATH` | `wcp-porting/sbnd:integration-2026-09-08/wct/cfg:sbnd_xin:photodet:wire-cell-data` |
| `LD_LIBRARY_PATH` | integration opt first, then validated opt |
| PBS queue | `by-gpu` / `neutrinoGPU::wirecell_2026` |
| Job walltime | 02:00:00 |
| CPUs | 16 (build jobs: `waf -j8`, `cmake --build -j8`) |

### Component library mapping (from CMakeLists analysis)

| Component | Library | Source |
|-----------|---------|--------|
| `wclsTensorSetLabeler` | `libWireCellAIML.so` | `larwirecell/aiml/` |
| `wclsTensorSetMetadataAttacher` | `libWireCellLarsoft.so` | `larwirecell/Components/` |
| `wclsTensorSetMetadataAttacher` build target | `cet_make_library(LIBRARY_NAME WireCellLarsoft ...)` | confirmed in Components/CMakeLists.txt |

### Build results

**PBS job:** `184899.sophia-pbs-01.lab.alcf.anl.gov` — **ALL 7 PHASES PASSED** — see full results in "Combined Build Phase" section below.

---

## Combined Build Phase (2026-09-09)

**Build environment:**
- Host: sophia-gpu-06
- Container: SLF7 (slf7.sif)
- Squashfs overlays: larsoft-v10_14_02.squashfs, sbnd-v10_14_02_04_delta.squashfs
- Env file: sbndcode-v10_14_02_04.env (sbndcode v10_14_02_04 / larsoft v10_14_02)
- Compiler: GCC 12.1.0 (Linux64bit+3.10-2.17)
- Container OS: Scientific Linux release 7.9 (Nitrogen)

**Build directories:**
- WCT isolated install: `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/build/opt`
- larwirecell cmake build: `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/build/mrb-build`
- larwirecell install: `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current/integration-2026-09-08/build/lwc-install`

**Build results table:**

| Check | WCT | larwirecell |
|-------|-----|-------------|
| Expected HEAD | `b2e3c6a9` | `5c50b2dc` |
| Actual HEAD | `b2e3c6a9b440af9f440151d5e9c9aa1771194bd0` | `5c50b2dc31a8b8f07b4afe4e1987884e2f298901` |
| Build environment | sbndcode-v10_14_02_04 / GCC 12.1.0 | sbndcode-v10_14_02_04 / GCC 12.1.0 |
| Build directory | `integration-2026-09-08/wct/build/` (waf) | `integration-2026-09-08/build/mrb-build/` (cmake) |
| Build PASS | ✓ | ✓ |
| Tests PASS | ✓ TrackFitting + matching_bundle + regression | N/A (build only) |
| Install path | `integration-2026-09-08/build/opt/` | `integration-2026-09-08/build/lwc-install/` |
| Correct integrated libraries loaded | ✓ INTEGRATION_OPT first in LD_LIBRARY_PATH | ✓ links against integration WCT |
| Required components available | N/A | ✓ wclsTensorSetLabeler + wclsTensorSetMetadataAttacher |
| Source worktree clean after build | ✓ | ✓ |

### Exact build commands

**WCT configure:**
```bash
python3 integration-2026-09-08/wct/wcb configure \
    --prefix=integration-2026-09-08/build/opt \
    --with-jsoncpp=$JSONCPP_FQ_DIR \
    --with-jsonnet=$GOJSONNET_FQ_DIR \
    --with-spdlog=yes \
    --with-eigen-include=$EIGEN_INC \
    --with-fftw=$FFTW_FQ_DIR \
    --with-fftw-include=$FFTW_INC \
    --with-fftw-lib=$FFTW_LIBRARY \
    --boost-includes=$BOOST_INC --boost-libs=$BOOST_LIB --boost-mt \
    --with-hdf5=$HDF5_FQ_DIR \
    --with-tbb=no \
    --with-root=$ROOTSYS \
    --with-bzip2-include=opt/include --with-bzip2-lib=opt/lib
```

**WCT build:**
```bash
python3 integration-2026-09-08/wct/wcb -j8 --notests install
```

**larwirecell cmake configure:**
```bash
cmake -S integration-2026-09-08/larwirecell \
      -B integration-2026-09-08/build/mrb-build \
      -DCMAKE_PREFIX_PATH="integration-2026-09-08/build/opt;..." \
      -DCMAKE_INSTALL_PREFIX=integration-2026-09-08/build/lwc-install \
      -DWIRECELL_FQ_DIR=integration-2026-09-08/build/opt \
      -DWireCell_INCLUDE_DIR=integration-2026-09-08/build/opt/include \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo
```

**larwirecell cmake build:**
```bash
cmake --build integration-2026-09-08/build/mrb-build -j8
```

### WCT test results

- TrackFitting narrow (TC-1, TC-2, TC-3): **PASS**
- matching_bundle_provenance (TC-A through TC-E): **PASS**
- Broader regression check (minus known data-dependent failures): **PASS**
- clus.jsonnet config: `stamp_matching_bundle_id`, `fast_xgb_forest`, `tcn_knobs`, MABC conditional key all present ✓

### Plugin/library path verification

- `wclsTensorSetLabeler` found via `strings libWireCellAIML.so`: **PRESENT**
- `wclsTensorSetMetadataAttacher` found via `strings libWireCellLarsoft.so`: **PRESENT**
- EventGraphIPC: **ABSENT** from libWireCellAIML.so and libWireCellLarsoft.so
- `ldd libWireCellAIML.so`: WireCell deps resolved from `integration-2026-09-08/build/opt/lib`
- `LD_LIBRARY_PATH` order: integration opt first, validated opt second

### Proposed 1-event input

| Field | Value |
|-------|-------|
| Input file | `/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/reference/extracted/02_workflow_test/test/test/prodgenie_bnb_nu_cosmic_sbnd_GenieGen-20260104T001558_G4-20260104T005212_589a580c-89e6-48bc-a036-f853689b5be3_DetSim-20260104T211819_DecoReco_CellTreeAPA0-20260109T035038.root` |
| SHA256 | `237b21363faba11fca49e54ce3f7f3b6faca5f4536887ca438332d2d19bb3b0a` |
| Run / SubRun / Event | 1 / 2728 / 1 |
| nskip | 0 |
| Base FCL | `wcls-img-clus-matching-xin.fcl` (from larwirecell build FCL dir) |
| FCL path | `integration-2026-09-08/build/mrb-build/fcl/` |

### Proposed 1-event command

```bash
# Environment additions needed for integration build:
export LD_LIBRARY_PATH=$INTEGRATION_LWC_LIB:$INTEGRATION_WCT_OPT/lib:${LD_LIBRARY_PATH}
export WIRECELL_PATH=$TMPSCE:$WCP_SBND:$WCT_INT_CFG:$SBND_XIN:$PHOTODET:$WCD_BASE
export FHICL_FILE_PATH=$WCP_SBND:$INTEGRATION_LWC_FCL:${FHICL_FILE_PATH}

# Run (from a per-event working directory):
/usr/bin/time -v $ART_FQ_DIR/bin/lar \
    --nskip 0 -n 1 \
    -c wcls-img-clus-matching-xin.fcl \
    -s /path/to/input.root \
    --no-output \
    > lar_run.log 2>&1
```

**Note:** Before running, the FCL and jsonnet config must be reviewed to ensure:
1. `WIRECELL_PATH` resolves to the INTEGRATION clus.jsonnet (not validated opt)
2. `LD_LIBRARY_PATH` places integration libs before validated libs
3. The SCE override jsonnet points to the Flare path (existing tmp-sce-override mechanism)
No FCL modifications made in this phase.

### Expected 1-event outputs

| Output | Path pattern | Notes |
|--------|-------------|-------|
| `nugraph.h5` | `<eventdir>/nugraph.h5` | Primary output; check sp/reco_bundle_id, sp/apa present |
| `mabc.zip` | via WCT pctree | Intermediate blob cluster tarball |
| `mabc-pr.zip` | via WCT pctree | Post-PR visitor tarball |
| `tracking-pr.root` | via WCT | Track fitting output |
| ART ROOT output | `--no-output` (suppressed for smoke) | Suppress with `--no-output` |
| `tf-default.root` | WCT native ROOT output | May be present if configured |


---

READY_FOR_1_EVENT_CONFIG_AND_EXECUTION_PHASE

---

## 1-Event Config and Execution Phase — 2026-09-09

### Pre-run configuration (Phases 0-8)

| Phase | Finding |
|-------|---------|
| Phase 0 (Pre-run audit) | WCT=b2e3c6a9 ✓ CLEAN; LWC=5c50b2dc ✓ CLEAN |
| Phase 2 (Input file) | SR=2728 / run=1 / subrun=2728 / event=1; size=3.7GB; SHA256=237b213... |
| Phase 4 (Config delta) | KEY FINDING: `iso_endpoint` removed from pr() API in b2e3c6a9; new params: `flash_by_gid`, `mcs_enable`, `fast_xgb_forest`, `tcn_knobs` |
| Phase 5 (NuGraph contract) | `stamp_matching_bundle_id=true` preserved; all required raw H5 fields in jsonnet |
| Phase 6 (TSL placement) | Single-instance post-PR; TensorSetMetadataAttacher available but not wired (rse_from_ident=true) |
| Phase 7 (Traditional outputs) | mabc.zip, mabc-pr.zip, nugraph.h5, ART ROOT, trash-all-apa.tar.gz; tracking-pr.root NOT expected (not in pipeline_names, same as validated) |
| Phase 8 (Static validation) | factory symbols verified; no EventGraphIPC |

### Integration-specific config

**New FCL:** `integration-2026-09-08/one-event-test/config/wcls-img-clus-integration-1evt.fcl`  
**New jsonnet:** `integration-2026-09-08/one-event-test/config/wcls-img-clus-integration-1evt.jsonnet`  
**Only change vs validated:** `iso_endpoint=true` removed from `clus_maker.pr()` call  
**stamp_matching_bundle_id=true:** preserved ✓

### PBS submission

**Job:** 184949  
**Script:** `haiwang-current/pbs_one_event_integration_2026_09_09.pbs`  
**Output log:** `integration-2026-09-08/one-event-test/logs/pbs_one_event_integration.log`  
**Container log:** `integration-2026-09-08/one-event-test/logs/container_one_event.log`  
**Python validation:** `haiwang-current/validate_one_event_integration.py`  
**Validation report:** `integration-2026-09-08/one-event-test/ONE_EVENT_INTEGRATION_VALIDATION_2026-09-09.md`

PBS job 184949 — ALL PHASES PASSED

### Results summary (PBS job 184949 + Python validation)

| Gate | Result |
| ---- | ------ |
| Integrated WCT actually loaded | ✓ b2e3c6a9 |
| Integrated larwirecell actually loaded | ✓ 5c50b2dc |
| Haiwang current reconstruction actually configured | ✓ iso_endpoint removed; stamp_matching_bundle_id=true |
| Event completed (lar exit 0) | ✓ |
| RSE correct everywhere | ✓ run=1 subrun=2728 event=1 |
| Traditional WCT outputs produced | ✓ mabc.zip(7.5MB) mabc-pr.zip trash-all-apa.tar.gz |
| tracking-pr.root produced | ✗ Not configured (same as validated) |
| BDT score branches present | ✗ Not configured (same as validated) |
| ART ROOT produced | ✓ 45MB |
| Raw nugraph.h5 produced | ✓ 2.1MB |
| Required raw NuGraph fields present | ✓ all 24 required fields |
| Bundle provenance populated/valid | ✓ 100.0% (6758/6758), 17 unique bundles |
| Segment provenance valid | ✓ 30 unique segments |
| CTPC topology source = 1 | ✓ |
| Raw graph indices valid | ✓ sp_nexus_sp=19773 edges; u/v/y nexus valid |
| Canonical adapter PASS | ✓ 2 APA samples; 0.3s |
| 2 canonical APA samples produced | ✓ 1_2728_rec-lab-apa0-1 (4915 SP) + 1_2728_rec-lab-apa1-1 (1843 SP) |
| Canonical schema compatible | ✓ 38 IDENTICAL_SCHEMA; 0 MISSING; 0 UNEXPECTED |
| NuGraph smoke PASS/NOT_RUN | NOT_RUN (libhcoll.so.1 unavailable outside container) |
| Ready for 48-event engineering validation | ✓ |

READY_FOR_48_EVENT_ENGINEERING_VALIDATION

---

READY_FOR_48_EVENT_ENGINEERING_VALIDATION

---

## Phase X — 48-Event Engineering Validation ✅ COMPLETE

**Date:** 2026-09-09  
**PBS job:** 184959  
**Config (frozen):**
- FCL: `wcls-img-clus-integration-1evt.fcl` SHA256 `2859f5c9...`
- jsonnet: `wcls-img-clus-integration-1evt.jsonnet` SHA256 `617e5561...`

**Run:** `lar --nskip 0 -n 48` — ONE persistent process, 48 events

### Aggregate measurements

| Metric | Value |
|--------|-------|
| Events processed | 48/48 |
| CTPC topology | 48/48 |
| KNN_FALLBACK | 0/48 |
| Total SPs | 228,461 |
| SPs/event | min=1060 max=12323 mean=4760 |
| Bundle provenance | 100.0% (0 sentinels) |
| Canonical APA samples | 96 (48 events × 2 APAs) |
| Canonical schema | 38 IDENTICAL, 0 MISSING, 0 UNEXPECTED |

### Output inventory (PBS job 184959)

| File | Size |
|------|------|
| `reco_wirecell_integration_1evt.root` | 1.8 GB |
| `mabc.zip` | 246 MB |
| `mabc-pr.zip` | 1.9 MB |
| `nugraph.h5` | 73 MB |
| `trash-all-apa.tar.gz` | 85 MB |
| `tf-default.root` | 8.0 KB |

### Final gate table

| Gate | Result |
| ---- | ------ |
| Integrated WCT loaded (b2e3c6a9) | ✓ |
| Integrated larwirecell loaded (5c50b2dc) | ✓ |
| Frozen config SHA256 verified | ✓ |
| 48 events completed (lar exit 0) | ✓ |
| 48 raw H5 records produced | ✓ |
| features[:,1]==reco_segment_id ALL 48 events | ✓ |
| Bundle provenance ≥90% ALL 48 events | ✓ 100% for every event |
| Exact edge-set equality ALL 48 events | ✓ |
| CTPC topology | 48/48 |
| KNN_FALLBACK | 0/48 |
| Traditional WCT outputs (mabc.zip etc.) | ✓ |
| ART ROOT produced | ✓ |
| Canonical adapter (96 samples) | ✓ |
| Canonical schema compatible | ✓ |
| NuGraph smoke | NOT_RUN (libhcoll.so.1 unavailable outside container) |

**Validation report:** `integration-2026-09-08/engineering-48evt/ENGINEERING_48EVENT_INTEGRATION_VALIDATION_2026-09-09.md`

READY_TO_FREEZE_INTEGRATED_DUAL_OUTPUT_RELEASE
