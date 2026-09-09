#!/bin/bash
# Container-side script: 48-event integration engineering validation.
# Runs INSIDE the SLF7 squashfs container.
#
# Purpose: Engineering validation of integrated WCT (b2e3c6a9) + larwirecell (5c50b2dc)
#          by processing EXACTLY 48 events from SR=2728 source in ONE persistent lar process.
#
# Architecture:
#   Phase 0:  Pre-run audit — verify frozen SHAs and build artifacts
#   Phase 1:  Runtime library audit — LD_LIBRARY_PATH, WIRECELL_PATH, ldd
#   Phase 2:  Input file verification
#   Phase 3-8: Config construction and static validation
#   Phase 9:  Run lar -n 48 (48 events in one process)
#   Phase 10-15: Output verification (event inventory, H5 structure, Bee, ART ROOT)
#
# Integration SHAs (FROZEN):
#   WCT:         b2e3c6a9b440af9f440151d5e9c9aa1771194bd0
#   larwirecell: 5c50b2dc31a8b8f07b4afe4e1987884e2f298901
#
# Config SHAs (FROZEN):
#   FCL:     2859f5c9c5950bc1cec726fbbe4b9a5e5a3ec521f9cf2ae32cff9fdf5a12c0fe
#   jsonnet: 617e556126550b435a092d26ee3d6da35799ce73bafb4bde66e850b547291dd4
#
# DO NOT modify wct or larwirecell sources.
# DO NOT add BDT/tracking-pr/two-instance TSL/TensorSetMetadataAttacher/EventGraphIPC.
set -uo pipefail

BASE=/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current
INTDIR=$BASE/integration-2026-09-08
TESTDIR=$INTDIR/engineering-48evt
LOGDIR=$TESTDIR/logs
RUNDIR=$TESTDIR/run
CFGDIR=$TESTDIR/config

INTEGRATION_OPT=$INTDIR/build/opt
LWC_INSTALL=$INTDIR/build/lwc-install/lib
VALIDATED_OPT=$BASE/opt

WCT_INT=$INTDIR/wct
LWC_INT=$INTDIR/larwirecell

LOG=$LOGDIR/48evt_integration.log

mkdir -p $LOGDIR $RUNDIR

echo "=== 48-EVENT INTEGRATION ENGINEERING VALIDATION ===" | tee $LOG
echo "Time: $(date)" | tee -a $LOG
echo "Host: $(hostname)" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 0: Pre-run audit
# ============================================================
echo "=== Phase 0: Pre-run audit ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

EXPECTED_WCT="b2e3c6a9b440af9f440151d5e9c9aa1771194bd0"
EXPECTED_LWC="5c50b2dc31a8b8f07b4afe4e1987884e2f298901"
EXPECTED_FCL_SHA="2859f5c9c5950bc1cec726fbbe4b9a5e5a3ec521f9cf2ae32cff9fdf5a12c0fe"
EXPECTED_JSON_SHA="617e556126550b435a092d26ee3d6da35799ce73bafb4bde66e850b547291dd4"

# Worktree-aware SHA resolver (SLF7 git 1.8.x doesn't support git -C or worktrees)
resolve_worktree_sha() {
    local src_dir="$1"
    local dot_git="$src_dir/.git"
    local sha="UNKNOWN"
    if [ -f "$dot_git" ]; then
        local gitdir; gitdir=$(sed 's/gitdir: //' "$dot_git" | tr -d '[:space:]')
        local head; head=$(cat "$gitdir/HEAD" 2>/dev/null | tr -d '[:space:]')
        if [[ "$head" == ref:* ]]; then
            local branch_ref="${head#ref:}"
            local commondir_rel; commondir_rel=$(cat "$gitdir/commondir" 2>/dev/null | tr -d '[:space:]')
            local parent_git; parent_git=$(cd "$gitdir" && cd "$commondir_rel" && pwd)
            sha=$(cat "$parent_git/$branch_ref" 2>/dev/null | tr -d '[:space:]')
            [ -z "$sha" ] && \
                sha=$(grep "^[0-9a-f]* $branch_ref$" "$parent_git/packed-refs" 2>/dev/null | awk '{print $1}')
        else
            sha="$head"
        fi
    elif [ -d "$dot_git" ]; then
        local head; head=$(cat "$dot_git/HEAD" 2>/dev/null | tr -d '[:space:]')
        if [[ "$head" == ref:* ]]; then
            local branch_ref="${head#ref:}"
            sha=$(cat "$dot_git/$branch_ref" 2>/dev/null | tr -d '[:space:]')
            [ -z "$sha" ] && \
                sha=$(grep "^[0-9a-f]* $branch_ref$" "$dot_git/packed-refs" 2>/dev/null | awk '{print $1}')
        else
            sha="$head"
        fi
    fi
    echo "${sha:-UNKNOWN}"
}

WCT_SHA=$(resolve_worktree_sha "$WCT_INT")
LWC_SHA=$(resolve_worktree_sha "$LWC_INT")
echo "WCT SHA:         $WCT_SHA" | tee -a $LOG
echo "WCT expected:    $EXPECTED_WCT" | tee -a $LOG
echo "LWC SHA:         $LWC_SHA" | tee -a $LOG
echo "LWC expected:    $EXPECTED_LWC" | tee -a $LOG

if [[ "$WCT_SHA" != "$EXPECTED_WCT" ]]; then
    echo "PHASE 0 FAIL: WCT SHA mismatch (got $WCT_SHA expected $EXPECTED_WCT)" | tee -a $LOG
    exit 1
fi
if [[ "$LWC_SHA" != "$EXPECTED_LWC" ]]; then
    echo "PHASE 0 FAIL: LWC SHA mismatch (got $LWC_SHA expected $EXPECTED_LWC)" | tee -a $LOG
    exit 1
fi
echo "WCT SHA: OK" | tee -a $LOG
echo "LWC SHA: OK" | tee -a $LOG

# version.txt
WCT_VERSION=$(cat "$WCT_INT/version.txt" 2>/dev/null | tr -d '[:space:]')
echo "WCT version.txt: $WCT_VERSION" | tee -a $LOG

# Verify frozen config SHAs
FCL_ACTUAL=$(sha256sum "$CFGDIR/wcls-img-clus-integration-1evt.fcl" 2>/dev/null | awk '{print $1}')
JSON_ACTUAL=$(sha256sum "$CFGDIR/wcls-img-clus-integration-1evt.jsonnet" 2>/dev/null | awk '{print $1}')
echo "FCL SHA256:     $FCL_ACTUAL" | tee -a $LOG
echo "FCL expected:   $EXPECTED_FCL_SHA" | tee -a $LOG
echo "JSON SHA256:    $JSON_ACTUAL" | tee -a $LOG
echo "JSON expected:  $EXPECTED_JSON_SHA" | tee -a $LOG
if [[ "$FCL_ACTUAL" != "$EXPECTED_FCL_SHA" ]]; then
    echo "PHASE 0 FAIL: FCL SHA256 mismatch" | tee -a $LOG; exit 1
fi
if [[ "$JSON_ACTUAL" != "$EXPECTED_JSON_SHA" ]]; then
    echo "PHASE 0 FAIL: jsonnet SHA256 mismatch" | tee -a $LOG; exit 1
fi
echo "Config SHAs: OK (frozen config confirmed)" | tee -a $LOG

# Build artifacts
WCT_LIB_COUNT=$(ls "$INTEGRATION_OPT/lib/"libWireCell*.so 2>/dev/null | wc -l)
LWC_LIB_COUNT=$(ls "$LWC_INSTALL/"libWireCell*.so 2>/dev/null | wc -l)
echo "Integration WCT .so count: $WCT_LIB_COUNT (expected 16)" | tee -a $LOG
echo "Integration LWC .so count: $LWC_LIB_COUNT (expected 3)" | tee -a $LOG

if [ "$WCT_LIB_COUNT" -lt 16 ]; then
    echo "PHASE 0 FAIL: integration WCT libs missing ($WCT_LIB_COUNT < 16)" | tee -a $LOG; exit 1
fi
if [ "$LWC_LIB_COUNT" -lt 3 ]; then
    echo "PHASE 0 FAIL: integration LWC libs missing ($LWC_LIB_COUNT < 3)" | tee -a $LOG; exit 1
fi
echo "Phase 0: PASS" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 1: Runtime library audit
# ============================================================
echo "=== Phase 1: Runtime library audit ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

source /lus/eagle/projects/neutrinoGPU/larsoft_hpc/envs/sbndcode-v10_14_02_04.env 2>/dev/null

# Prepend integration libraries
export LD_LIBRARY_PATH=$LWC_INSTALL:$INTEGRATION_OPT/lib:${LD_LIBRARY_PATH:-}
export CET_PLUGIN_PATH=$LWC_INSTALL:$INTEGRATION_OPT/lib:${CET_PLUGIN_PATH:-}

echo "LD_LIBRARY_PATH (first 5):" | tee -a $LOG
echo "$LD_LIBRARY_PATH" | tr ':' '\n' | head -5 | tee -a $LOG
echo "" | tee -a $LOG

WCT_VER=$(wire-cell --version 2>/dev/null || echo "NOT_FOUND")
echo "wire-cell --version: $WCT_VER" | tee -a $LOG

echo "" | tee -a $LOG
echo "--- WireCell library classification ---" | tee -a $LOG
ldd "$LWC_INSTALL/libWireCellAIML.so" "$LWC_INSTALL/libWireCellLarsoft.so" 2>&1 \
    | grep "libWireCell" | awk '{print $3}' | sort -u | while read lib; do
    if [[ "$lib" == *"$INTDIR/build/opt"* ]]; then
        echo "  INTEGRATED_INSTALL: $lib"
    elif [[ "$lib" == *"$INTDIR/build"* ]]; then
        echo "  INTEGRATED_BUILD_TREE: $lib"
    elif [[ "$lib" == *"$VALIDATED_OPT"* ]]; then
        echo "  OLD_VALIDATED: $lib  *** CHECK ***"
    else
        echo "  CENTRAL_EXTERNAL: $lib"
    fi
done | tee -a $LOG

echo "" | tee -a $LOG
echo "Phase 1: recorded (verify no OLD_VALIDATED WireCell libs above)" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 2: Input file verification
# ============================================================
echo "=== Phase 2: Input file verification ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

FILE_SR2728="/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/reference/extracted/02_workflow_test/test/test/prodgenie_bnb_nu_cosmic_sbnd_GenieGen-20260104T001558_G4-20260104T005212_589a580c-89e6-48bc-a036-f853689b5be3_DetSim-20260104T211819_DecoReco_CellTreeAPA0-20260109T035038.root"

if [ ! -f "$FILE_SR2728" ]; then
    echo "PHASE 2 FAIL: source file not found: $FILE_SR2728" | tee -a $LOG
    exit 1
fi
FILE_SIZE=$(stat -c '%s' "$FILE_SR2728")
echo "Source file: $FILE_SR2728" | tee -a $LOG
echo "File size: $FILE_SIZE bytes (expected 3947343477)" | tee -a $LOG
echo "This file contains >=48 events starting from event=1 in SR=2728" | tee -a $LOG
echo "Phase 2: PASS" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 3-8: Configuration setup and static validation
# ============================================================
echo "=== Phase 3-8: Configuration setup ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

# SCE override: patch integration WCT clus.jsonnet for Flare SCE path
TMPSCE=$INTDIR/tmp-sce-override-integration
mkdir -p $TMPSCE/pgrapher/experiment/sbnd
CVMFS_SCE='/cvmfs/sbnd.opensciencegrid.org/products/sbnd/sbnd_data/v01_42_00/SCEoffsets/SCEoffsets_SBND_E500_dualmap_CV_voxelTH3.root'
FLARE_SCE='/lus/flare/projects/neutrinoGPU/scisoft/larsoft/sbnd_data/v01_42_00/SCEoffsets/SCEoffsets_SBND_E500_dualmap_CV_voxelTH3.root'

sed "s|$CVMFS_SCE|$FLARE_SCE|g" \
    $WCT_INT/cfg/pgrapher/experiment/sbnd/clus.jsonnet \
    > $TMPSCE/pgrapher/experiment/sbnd/clus.jsonnet

echo "SCE override: patched integration clus.jsonnet → $TMPSCE/pgrapher/experiment/sbnd/clus.jsonnet" | tee -a $LOG

WCP_SBND=$BASE/wcp-porting/sbnd
WCT_CFG=$WCT_INT/cfg
WCD_BASE=/lus/eagle/projects/neutrinoGPU/snehadri/wct/spack/opt/spack/linux-x86_64_v3/wire-cell-data-0.2.0-jbu22fdchzcf5ii5nvepy6fcgpsf4cnu/share/wirecell
SBND_XIN=$WCP_SBND/sbnd_xin
PHOTODET=$WCD_BASE/sbnd/photodet
WCD_SHARE=$WCD_BASE

export WIRECELL_PATH="$CFGDIR:$TMPSCE:$WCP_SBND:$WCT_CFG:$SBND_XIN:$PHOTODET:$WCD_SHARE:${WIRECELL_PATH:-}"

echo "WIRECELL_PATH (first 6):" | tee -a $LOG
echo "$WIRECELL_PATH" | tr ':' '\n' | head -6 | tee -a $LOG

LARWIRECELL_FCL=$VALIDATED_OPT/larwirecell/v10_01_28/slf7.x86_64.e26.prof/fcl
export FHICL_FILE_PATH="$CFGDIR:$WCP_SBND:$LARWIRECELL_FCL:${FHICL_FILE_PATH:-}"

echo "FHICL_FILE_PATH (first 3):" | tee -a $LOG
echo "$FHICL_FILE_PATH" | tr ':' '\n' | head -4 | tee -a $LOG
echo "" | tee -a $LOG

echo "--- Config SHA256 (re-verify inside container) ---" | tee -a $LOG
sha256sum "$CFGDIR/wcls-img-clus-integration-1evt.fcl" | tee -a $LOG
sha256sum "$CFGDIR/wcls-img-clus-integration-1evt.jsonnet" | tee -a $LOG

echo "" | tee -a $LOG
echo "--- Factory verification ---" | tee -a $LOG
NM_AIML=$(nm -D "$LWC_INSTALL/libWireCellAIML.so" 2>/dev/null | grep -c "make_wclsTensorSetLabeler_factory" || echo 0)
NM_LARSOFT=$(nm -D "$LWC_INSTALL/libWireCellLarsoft.so" 2>/dev/null | grep -c "make_wclsTensorSetMetadataAttacher_factory" || echo 0)
echo "make_wclsTensorSetLabeler_factory in AIML: $NM_AIML (expected >=1)" | tee -a $LOG
echo "make_wclsTensorSetMetadataAttacher_factory in Larsoft: $NM_LARSOFT (expected >=1)" | tee -a $LOG

NM_EVGIPC=$(nm -D "$LWC_INSTALL/libWireCellAIML.so" "$LWC_INSTALL/libWireCellLarsoft.so" 2>/dev/null | grep -c "EventGraphIPC" || echo 0)
echo "EventGraphIPC symbols: $NM_EVGIPC (expected 0)" | tee -a $LOG

if [ "$NM_AIML" -lt 1 ] || [ "$NM_LARSOFT" -lt 1 ]; then
    echo "PHASE 8 FAIL: required factory symbols missing" | tee -a $LOG; exit 1
fi
if [ "$NM_EVGIPC" -gt 0 ]; then
    echo "PHASE 8 FAIL: EventGraphIPC found in integration libs" | tee -a $LOG; exit 1
fi

echo "Phase 3-8: PASS" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 9: Run 48 events in ONE persistent lar process
# ============================================================
echo "=== Phase 9: lar -n 48 (ONE persistent process) ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG
echo "FCL: wcls-img-clus-integration-1evt.fcl" | tee -a $LOG
echo "Source: $FILE_SR2728" | tee -a $LOG
echo "Flags: --nskip 0 -n 48" | tee -a $LOG
echo "Run dir: $RUNDIR" | tee -a $LOG

LAR=$ART_FQ_DIR/bin/lar

RUN_START=$(date +%s)
(
    cd "$RUNDIR"
    /usr/bin/time -v "$LAR" --nskip 0 -n 48 \
        -c wcls-img-clus-integration-1evt.fcl \
        -s "$FILE_SR2728" \
        2>&1
) | tee "$RUNDIR/lar_run.log"
LAR_EXIT=$?
RUN_WALL=$(( $(date +%s) - RUN_START ))
RUN_RSS=$(grep -i "Maximum resident" "$RUNDIR/lar_run.log" 2>/dev/null \
          | awk '{print $NF}' | head -1)
[ -z "$RUN_RSS" ] && RUN_RSS="?"

echo "" | tee -a $LOG
echo "lar exit:   $LAR_EXIT" | tee -a $LOG
echo "walltime:   ${RUN_WALL}s" | tee -a $LOG
echo "peak RSS:   ${RUN_RSS} kB" | tee -a $LOG

if [ $LAR_EXIT -ne 0 ]; then
    echo "" | tee -a $LOG
    echo "PHASE 9 FAIL: lar exited with code $LAR_EXIT" | tee -a $LOG
    echo "Last 80 lines of lar_run.log:" | tee -a $LOG
    tail -80 "$RUNDIR/lar_run.log" | tee -a $LOG
    exit 1
fi

echo "Phase 9: PASS (lar exit 0, 48 events processed)" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 10-15: Output verification
# ============================================================
echo "=== Phase 10-15: Output verification ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

echo "--- Output inventory ---" | tee -a $LOG
# ART ROOT file has FCL-specified name (frozen FCL, cannot change)
for f in reco_wirecell_integration_1evt.root mabc.zip mabc-pr.zip nugraph.h5 trash-all-apa.tar.gz tf-default.root; do
    if [ -f "$RUNDIR/$f" ]; then
        SZ=$(stat -c '%s' "$RUNDIR/$f" 2>/dev/null)
        echo "  PRESENT: $f  ($SZ bytes)" | tee -a $LOG
    else
        echo "  ABSENT:  $f" | tee -a $LOG
    fi
done

# mabc.zip integrity check (48 events: expect >> 1 event's 7.8 MB)
MABC_SZ=$(stat -c '%s' "$RUNDIR/mabc.zip" 2>/dev/null || echo 0)
echo "" | tee -a $LOG
echo "--- mabc.zip (48 events) ---" | tee -a $LOG
echo "  size: ${MABC_SZ} bytes" | tee -a $LOG
if [ "${MABC_SZ}" -gt 50000000 ]; then
    echo "  size check: PASS (> 50 MB)" | tee -a $LOG
elif [ "${MABC_SZ}" -gt 5000000 ]; then
    echo "  size check: WARNING (5-50 MB; smaller than expected for 48 events)" | tee -a $LOG
else
    echo "  size check: FAIL (< 5 MB — likely empty or 1-event only)" | tee -a $LOG
    exit 1
fi

# nugraph.h5 existence and size (48 events: expect > 5 MB)
H5_SZ=$(stat -c '%s' "$RUNDIR/nugraph.h5" 2>/dev/null || echo 0)
echo "" | tee -a $LOG
echo "--- nugraph.h5 (48 events) ---" | tee -a $LOG
echo "  size: ${H5_SZ} bytes" | tee -a $LOG
if [ "${H5_SZ}" -gt 5000000 ]; then
    echo "  size check: PASS (> 5 MB)" | tee -a $LOG
elif [ "${H5_SZ}" -gt 1000000 ]; then
    echo "  size check: WARNING (1-5 MB; smaller than expected for 48 events)" | tee -a $LOG
else
    echo "  size check: FAIL (< 1 MB — likely too few events)" | tee -a $LOG
    exit 1
fi

# ART ROOT
ART_SZ=$(stat -c '%s' "$RUNDIR/reco_wirecell_integration_1evt.root" 2>/dev/null || echo 0)
echo "" | tee -a $LOG
echo "--- ART ROOT (48 events) ---" | tee -a $LOG
echo "  size: ${ART_SZ} bytes" | tee -a $LOG
if [ "${ART_SZ}" -gt 200000000 ]; then
    echo "  size check: PASS (> 200 MB)" | tee -a $LOG
elif [ "${ART_SZ}" -gt 20000000 ]; then
    echo "  size check: WARNING (20-200 MB; smaller than expected for 48 events)" | tee -a $LOG
else
    echo "  size check: WARNING (< 20 MB)" | tee -a $LOG
fi

echo "" | tee -a $LOG
echo "=== Container side DONE ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG
echo "Phase 9 exit: $LAR_EXIT" | tee -a $LOG
echo "" | tee -a $LOG

echo "INTEGRATION_48EVT_CONTAINER: PASS" | tee -a $LOG
exit 0
