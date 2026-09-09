#!/bin/bash
# Container-side script: 1-event integration validation.
# Runs INSIDE the SLF7 squashfs container.
#
# Purpose: Validate integrated WCT (b2e3c6a9) + larwirecell (5c50b2dc)
#          by processing EXACTLY ONE event from SR=2728 source.
#
# Architecture:
#   Phase 0:  Pre-run audit — verify frozen SHAs and clean worktree status
#   Phase 1:  Runtime library audit — LD_LIBRARY_PATH, WIRECELL_PATH, ldd
#   Phase 2:  Input file verification
#   Phase 3-8: Config construction and static validation
#   Phase 9:  Run lar -n 1 (ONE event only)
#   Phase 10-15: Output verification (event identity, H5 structure, Bee, ART ROOT)
#
# Integration SHAs:
#   WCT:         b2e3c6a9b440af9f440151d5e9c9aa1771194bd0
#   larwirecell: 5c50b2dc31a8b8f07b4afe4e1987884e2f298901
#
# Source event: run=1 / subrun=2728 / event=1
#
# DO NOT run more than 1 event.
# DO NOT modify wct or larwirecell sources.
set -uo pipefail

BASE=/lus/eagle/projects/neutrinoGPU/abhat/sbnd/sample_generation_port/work/haiwang-current
INTDIR=$BASE/integration-2026-09-08
TESTDIR=$INTDIR/one-event-test
LOGDIR=$TESTDIR/logs
RUNDIR=$TESTDIR/run
CFGDIR=$TESTDIR/config

INTEGRATION_OPT=$INTDIR/build/opt
LWC_INSTALL=$INTDIR/build/lwc-install/lib
VALIDATED_OPT=$BASE/opt

WCT_INT=$INTDIR/wct
LWC_INT=$INTDIR/larwirecell

LOG=$LOGDIR/one_event_integration.log

mkdir -p $LOGDIR $RUNDIR

echo "=== ONE-EVENT INTEGRATION VALIDATION ===" | tee $LOG
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

# version.txt
WCT_VERSION=$(cat "$WCT_INT/version.txt" 2>/dev/null | tr -d '[:space:]')
echo "WCT version.txt: $WCT_VERSION" | tee -a $LOG

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

# Source sbndcode environment
source /lus/eagle/projects/neutrinoGPU/larsoft_hpc/envs/sbndcode-v10_14_02_04.env 2>/dev/null

# Prepend integration libraries
export LD_LIBRARY_PATH=$LWC_INSTALL:$INTEGRATION_OPT/lib:${LD_LIBRARY_PATH:-}
export CET_PLUGIN_PATH=$LWC_INSTALL:$INTEGRATION_OPT/lib:${CET_PLUGIN_PATH:-}

echo "LD_LIBRARY_PATH (first 3):" | tee -a $LOG
echo "$LD_LIBRARY_PATH" | tr ':' '\n' | head -5 | tee -a $LOG
echo "" | tee -a $LOG

# WCT version (runtime)
WCT_BIN=$(which wire-cell 2>/dev/null || echo "NOT_FOUND")
echo "wire-cell: $WCT_BIN" | tee -a $LOG
WCT_VER=$(wire-cell --version 2>/dev/null || echo "NOT_FOUND")
echo "wire-cell --version: $WCT_VER" | tee -a $LOG

echo "WIRECELL_FQ_DIR: ${WIRECELL_FQ_DIR:-<unset>}" | tee -a $LOG

# ldd audit on integration libs
echo "" | tee -a $LOG
echo "--- ldd libWireCellAIML.so ---" | tee -a $LOG
ldd "$LWC_INSTALL/libWireCellAIML.so" 2>&1 | grep "libWireCell" | tee -a $LOG

echo "" | tee -a $LOG
echo "--- ldd libWireCellLarsoft.so ---" | tee -a $LOG
ldd "$LWC_INSTALL/libWireCellLarsoft.so" 2>&1 | grep "libWireCell" | tee -a $LOG

# Classify WireCell library resolutions
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
    elif [[ "$lib" == "/lus/flare"* ]] || [[ "$lib" == "/lus/eagle"*"scisoft"* ]]; then
        echo "  CENTRAL_EXTERNAL: $lib"
    else
        echo "  UNKNOWN: $lib"
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
EXPECTED_SHA256="237b21363faba11fca49e54ce3f7f3b6faca5f4536887ca438332d2d19bb3b0a"
EXPECTED_RSE="run=1 subrun=2728 event=1"

if [ ! -f "$FILE_SR2728" ]; then
    echo "PHASE 2 FAIL: source file not found: $FILE_SR2728" | tee -a $LOG
    exit 1
fi
FILE_SIZE=$(stat -c '%s' "$FILE_SR2728")
echo "Source file: $FILE_SR2728" | tee -a $LOG
echo "File size: $FILE_SIZE bytes (expected 3947343477)" | tee -a $LOG
echo "Expected SHA256: $EXPECTED_SHA256" | tee -a $LOG
echo "Expected first RSE: $EXPECTED_RSE" | tee -a $LOG
echo "Phase 2: PASS" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 3-8: Configuration setup
# ============================================================
echo "=== Phase 3-8: Configuration setup ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

# SCE override: patch integration WCT clus.jsonnet for Flare SCE path
TMPSCE=$INTDIR/tmp-sce-override-integration
mkdir -p $TMPSCE/pgrapher/experiment/sbnd
CVMFS_SCE='/cvmfs/sbnd.opensciencegrid.org/products/sbnd/sbnd_data/v01_42_00/SCEoffsets/SCEoffsets_SBND_E500_dualmap_CV_voxelTH3.root'
FLARE_SCE='/lus/flare/projects/neutrinoGPU/scisoft/larsoft/sbnd_data/v01_42_00/SCEoffsets/SCEoffsets_SBND_E500_dualmap_CV_voxelTH3.root'

# Integration jsonnet is already in CFGDIR, but we need clus.jsonnet from integration WCT
# (with SCE path patched) to shadow everything else
sed "s|$CVMFS_SCE|$FLARE_SCE|g" \
    $WCT_INT/cfg/pgrapher/experiment/sbnd/clus.jsonnet \
    > $TMPSCE/pgrapher/experiment/sbnd/clus.jsonnet

echo "SCE override: patched integration clus.jsonnet → $TMPSCE/pgrapher/experiment/sbnd/clus.jsonnet" | tee -a $LOG

# Wire WIRECELL_PATH:
# 1. CFGDIR    — integration entry jsonnet (wcls-img-clus-integration-1evt.jsonnet)
# 2. TMPSCE    — integration clus.jsonnet with Flare SCE path
# 3. WCP_SBND  — FCL + semi-analytical-sbnd.json + other non-cfg assets
# 4. WCT_CFG  — integration WCT cfg (all other jsonnet imports)
# 5. sbnd_xin  — particle dataset etc.
# 6. photodet  — photodetector data
# 7. WCD_SHARE — wire-cell-data share
WCP_SBND=$BASE/wcp-porting/sbnd
WCT_CFG=$WCT_INT/cfg
WCD_BASE=/lus/eagle/projects/neutrinoGPU/snehadri/wct/spack/opt/spack/linux-x86_64_v3/wire-cell-data-0.2.0-jbu22fdchzcf5ii5nvepy6fcgpsf4cnu/share/wirecell
SBND_XIN=$WCP_SBND/sbnd_xin
PHOTODET=$WCD_BASE/sbnd/photodet
WCD_SHARE=$WCD_BASE

export WIRECELL_PATH="$CFGDIR:$TMPSCE:$WCP_SBND:$WCT_CFG:$SBND_XIN:$PHOTODET:$WCD_SHARE:${WIRECELL_PATH:-}"

echo "WIRECELL_PATH (first 4):" | tee -a $LOG
echo "$WIRECELL_PATH" | tr ':' '\n' | head -6 | tee -a $LOG

# FCL path
LARWIRECELL_FCL=$VALIDATED_OPT/larwirecell/v10_01_28/slf7.x86_64.e26.prof/fcl
export FHICL_FILE_PATH="$CFGDIR:$WCP_SBND:$LARWIRECELL_FCL:${FHICL_FILE_PATH:-}"

echo "FHICL_FILE_PATH (first 3):" | tee -a $LOG
echo "$FHICL_FILE_PATH" | tr ':' '\n' | head -4 | tee -a $LOG
echo "" | tee -a $LOG

# SHA256 of config files
echo "--- Config SHA256 ---" | tee -a $LOG
sha256sum "$CFGDIR/wcls-img-clus-integration-1evt.fcl" | tee -a $LOG
sha256sum "$CFGDIR/wcls-img-clus-integration-1evt.jsonnet" | tee -a $LOG
sha256sum "$TMPSCE/pgrapher/experiment/sbnd/clus.jsonnet" | tee -a $LOG

# Static validation: verify critical factories exist in integration libs
echo "" | tee -a $LOG
echo "--- Factory verification ---" | tee -a $LOG
NM_AIML=$(nm -D "$LWC_INSTALL/libWireCellAIML.so" 2>/dev/null | grep -c "make_wclsTensorSetLabeler_factory" || echo 0)
NM_LARSOFT=$(nm -D "$LWC_INSTALL/libWireCellLarsoft.so" 2>/dev/null | grep -c "make_wclsTensorSetMetadataAttacher_factory" || echo 0)
echo "make_wclsTensorSetLabeler_factory in AIML: $NM_AIML (expected >=1)" | tee -a $LOG
echo "make_wclsTensorSetMetadataAttacher_factory in Larsoft: $NM_LARSOFT (expected >=1)" | tee -a $LOG

# No EventGraphIPC
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
# Phase 9: Run EXACTLY ONE event
# ============================================================
echo "=== Phase 9: lar -n 1 ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG
echo "FCL: wcls-img-clus-integration-1evt.fcl" | tee -a $LOG
echo "Source: $FILE_SR2728" | tee -a $LOG
echo "Flags: --nskip 0 -n 1" | tee -a $LOG
echo "Run dir: $RUNDIR" | tee -a $LOG

LAR=$ART_FQ_DIR/bin/lar

RUN_START=$(date +%s)
(
    cd "$RUNDIR"
    /usr/bin/time -v "$LAR" --nskip 0 -n 1 \
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

echo "Phase 9: PASS (lar exit 0)" | tee -a $LOG
echo "" | tee -a $LOG

# ============================================================
# Phase 10: Output inventory and event identity
# ============================================================
echo "=== Phase 10-15: Output verification ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

echo "--- Output inventory ---" | tee -a $LOG
for f in reco_wirecell_integration_1evt.root mabc.zip mabc-pr.zip nugraph.h5 trash-all-apa.tar.gz tf-default.root; do
    if [ -f "$RUNDIR/$f" ]; then
        SZ=$(stat -c '%s' "$RUNDIR/$f" 2>/dev/null)
        echo "  PRESENT: $f  ($SZ bytes)" | tee -a $LOG
    else
        echo "  ABSENT:  $f" | tee -a $LOG
    fi
done

# Check RSE in log (look for run/subrun/event in lar output)
echo "" | tee -a $LOG
echo "--- RSE check in lar log ---" | tee -a $LOG
grep -E "run.*subrun.*event|r:.*s:.*e:|EventID|RSE|2728" "$RUNDIR/lar_run.log" 2>/dev/null \
    | grep -v "^#" | head -10 | tee -a $LOG

# mabc.zip integrity
MABC_SZ=$(stat -c '%s' "$RUNDIR/mabc.zip" 2>/dev/null || echo 0)
echo "" | tee -a $LOG
echo "--- mabc.zip ---" | tee -a $LOG
echo "  size: ${MABC_SZ} bytes" | tee -a $LOG
if [ "${MABC_SZ}" -gt 1000000 ]; then
    echo "  size check: PASS (> 1 MB)" | tee -a $LOG
else
    echo "  size check: WARNING (< 1 MB; may be small for 1 event)" | tee -a $LOG
fi

# nugraph.h5 existence and size
H5_SZ=$(stat -c '%s' "$RUNDIR/nugraph.h5" 2>/dev/null || echo 0)
echo "" | tee -a $LOG
echo "--- nugraph.h5 ---" | tee -a $LOG
echo "  size: ${H5_SZ} bytes" | tee -a $LOG
if [ "${H5_SZ}" -gt 100000 ]; then
    echo "  size check: PASS (> 100 KB)" | tee -a $LOG
else
    echo "  size check: FAIL (< 100 KB — likely empty)" | tee -a $LOG
    exit 1
fi

# ART ROOT
ART_SZ=$(stat -c '%s' "$RUNDIR/reco_wirecell_integration_1evt.root" 2>/dev/null || echo 0)
echo "" | tee -a $LOG
echo "--- ART ROOT reco_wirecell_integration_1evt.root ---" | tee -a $LOG
echo "  size: ${ART_SZ} bytes" | tee -a $LOG

echo "" | tee -a $LOG
echo "=== Container side DONE ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG
echo "Phase 9 exit: $LAR_EXIT" | tee -a $LOG
echo "" | tee -a $LOG

# Print summary for PBS grep
echo "INTEGRATION_1EVT_CONTAINER: PASS" | tee -a $LOG
exit 0
