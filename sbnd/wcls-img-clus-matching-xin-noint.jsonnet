// NO-INTERMEDIATE mode of wcls-img-clus-matching-xin.jsonnet.
// Identical reconstruction; all event-data file-producing side-effects disabled:
//   nugraph.h5        -- suppressed: hdf5_output=true, hdf5_file_output=false in labeler
//   trash-all-apa.tar.gz -- suppressed: ClusterFlashDump terminal (no-file sink)
//   mabc.zip          -- suppressed: bee_noint sink used instead (different name)
//   mabc-pr.zip       -- suppressed: bee_sink=bee_noint passed to PR MABC via
//                        local clus.jsonnet override in wcp-porting/sbnd/pgrapher/
//                        experiment/sbnd/clus.jsonnet (shadowed in WIRECELL_PATH)
//
// One Bee archive remains: nointermediate-debug-bee.zip (all MABC + labeler Bee
// data consolidated -- OPTIONAL TERMINAL DIAGNOSTIC, nothing reads it).
//
// The canonical H5 is written by run_canonical_receiver.py entirely from in-memory
// arrays transported over the Unix socket (EventGraphIPC) -- NO intermediate file.

local g = import "pgraph.jsonnet";
local wc = import "wirecell.jsonnet";

local tools_maker = import 'pgrapher/common/tools.jsonnet';

local reality = std.extVar('reality');

local params = import 'pgrapher/experiment/sbnd/simparams.jsonnet';

local tools_all = tools_maker(params);
local tools = tools_all {anodes: [tools_all.anodes[n] for n in [0, 1]]};
local nanode = std.length(tools.anodes);

// ---- artROOT inputs ----
local wcls_input = {
    sigs: g.pnode({
        type: 'wclsCookedFrameSource',
        name: 'sigs',
        data: {
            nticks: params.daq.nticks,
            frame_scale: 50,
            summary_scale: 50,
            frame_tags: ["orig"],
            recobwire_tags: std.extVar('recobwire_tags'),
            trace_tags: std.extVar('trace_tags'),
            summary_tags: std.extVar('summary_tags'),
            input_mask_tags: std.extVar('input_mask_tags'),
            output_mask_tags: std.extVar('output_mask_tags'),
        },
    }, nin=0, nout=1),
    opflashes0: g.pnode({
        type: 'wclsOpFlashSource',
        name: 'tpc0',
        data: { art_tag: std.extVar('opflash0_input_label') },
    }, nin=0, nout=1),
    opflashes1: g.pnode({
        type: 'wclsOpFlashSource',
        name: 'tpc1',
        data: { art_tag: std.extVar('opflash1_input_label') },
    }, nin=0, nout=1),
    opflashes: [wcls_input.opflashes0, wcls_input.opflashes1],
};

// ---- frame fanout ----
local fanout_rules = [
    {
        frame: { '.*': 'orig%d' % tools.anodes[n].data.ident },
        trace: {
            gauss: 'gauss%d' % tools.anodes[n].data.ident,
            wiener: 'wiener%d' % tools.anodes[n].data.ident,
        },
    }
    for n in std.range(0, nanode - 1)
];
local frame_fan = g.pnode({
    type: 'FrameFanout',
    name: 'sig_fanout',
    data: { multiplicity: nanode, tag_rules: fanout_rules },
}, nin=1, nout=nanode);

// ---- imaging ----
local img = import 'pgrapher/experiment/sbnd/img.jsonnet';
local img_maker = img();
local img_pipes = [
    img_maker.per_anode(tools.anodes[n], 'multi-3view', add_dump=false, full_deghost=true)
    for n in std.range(0, nanode - 1)
];

// ---- clustering ----
// Imports the local override (wcp-porting/sbnd/pgrapher/experiment/sbnd/clus.jsonnet)
// which shadows the frozen WCT clus.jsonnet in WIRECELL_PATH.  The override adds
// bee_sink support to clus_pr()/pr() -- no other behavior change.
local clus = import 'pgrapher/experiment/sbnd/clus.jsonnet';
local clus_maker = clus(rse_from_ident=true, reality=reality);

// Single shared Bee sink for ALL MABC nodes + labeler + PR MABC.
// Consolidates all visualization output into one archive; nothing reads it.
local bee_noint = {
    type: 'BeeSink',
    name: 'noint_bee',
    data: { outname: 'nointermediate-debug-bee.zip', initial_index: 0 },
};

local clus_pipes = [
    clus_maker.per_apa(tools.anodes[n], dump=false, bee_sink=bee_noint, save_assoc_id=true)
    for n in std.range(0, nanode - 1)
];

// ---- Q/L matching ----
local semimodel_file = 'semi-analytical-sbnd.json';
local pmt_nl = true;

local qlm = (import 'pgrapher/experiment/sbnd/qlmatching.jsonnet')(params);
local cathode_fv = (import 'pgrapher/experiment/sbnd/cathode_fiducial.jsonnet')(
    cx=0.5*wc.cm, cy=0.5*wc.cm, cz=0.5*wc.cm);
local flash_attach = [qlm.flash_attach(n) for n in std.range(0, nanode - 1)];
local matching_joint = qlm.matching_joint(
    tools.anodes, clus_maker.detector_volumes(tools.anodes),
    reality, semimodel_file, cathode_fiducial=cathode_fv.tn, pmt_nl=pmt_nl);

local clus_all_apa = clus_maker.all_apa(tools.anodes, dump=false,
                                        bee_sink=bee_noint, premerged=true,
                                        save_real_cluster_id=true,
                                        save_assoc_cluster_id=true);

// ==== follow-up tail ====
local beam_window = [0.2 * wc.us, 2.2 * wc.us];

local pds = (import 'pgrapher/experiment/sbnd/particle_dataset.jsonnet')();
local pr_node = clus_maker.pr(
    tools.anodes, dump=false,
    pipeline_names=['switch_scope', 'unmerge_bundle', 'unmerge_assoc', 'steiner',
                    'fiducialutils', 'tagger_check_tgm', 'tagger_check_stm', 'tagger_check_fc'],
    particle_dataset=pds.particle_dataset, extra_uses=pds.all, beam_window=beam_window,
    iso_endpoint=true,
    stamp_matching_bundle_id=true,
    // Route PR MABC Bee output to bee_noint: suppresses mabc-pr.zip.
    // Requires the local clus.jsonnet override in wcp-porting/sbnd/pgrapher/.
    bee_sink=bee_noint);

local lbl_dv = clus_maker.detector_volumes(tools.anodes, face='');
local lbl_pcts = clus_maker.pc_transforms(lbl_dv);
local lbl_fv = clus_maker.fiducial_box();
local labeler = g.pnode({
    type: 'wclsTensorSetLabeler',
    name: 'clus_all_apa',
    data: {
        inpath: 'pointtrees/%d',
        grouping: 'live',
        reality: reality,
        anodes: [wc.tn(anode) for anode in tools.anodes],
        detector_volumes: wc.tn(lbl_dv),
        pc_transforms: wc.tn(lbl_pcts),
        drift_speed: clus_maker.drift_speed,
        time_offset: clus_maker.time_offset,
        tick: 0.5 * wc.us,
        sce_field: wc.tn(clus_maker.sce_field_fwd),
        sce_correction: true,
        n_sample_truth_depo_sce: 1,
        pf_ke_min: 10 * wc.MeV,
        pf_fiducial: wc.tn(lbl_fv),
        pf_nu_only: true,
        truth_tracks_nu_only: true,
        // bee_sink present: tagger Bee sets go to bee_noint (consolidated archive).
        bee_sink: wc.tn(bee_noint),
        tagger_coords: clus_maker.bee_coords,
        beam_window: beam_window,
        // hdf5_output=true: build EventGraph + send IPC (required for IPC transport).
        // hdf5_file_output=false: suppress nugraph.h5 file write in finalize().
        // Canonical H5 comes from in-memory IPC only; no file intermediate.
        hdf5_output: true,
        hdf5_file_output: false,
    },
}, nin=1, nout=1,
   uses=tools.anodes + [lbl_dv, lbl_pcts, clus_maker.sce_field_fwd, lbl_fv, bee_noint]);

// Terminal: ClusterFlashDump (ITensorSetSink, WireCellAux -- already loaded).
// Deserializes the pctree and logs it; writes NO files.
// Replaces TensorFileSink to suppress trash-all-apa.tar.gz.
local cfd_terminal = g.pnode({
    type: 'ClusterFlashDump',
    name: 'clus_all_apa',
    // Labeler re-serializes at livepath = "pointtrees/%d/live" (inpath + grouping).
    data: { datapath: 'pointtrees/%d/live' },
}, nin=1, nout=0);

// ---- graph ----
local graph = g.intern(
    innodes=[wcls_input.sigs],
    centernodes=[frame_fan] + img_pipes + clus_pipes + flash_attach
                + [matching_joint] + wcls_input.opflashes
                + [clus_all_apa, pr_node, labeler],
    outnodes=[cfd_terminal],
    edges=
        [g.edge(wcls_input.sigs, frame_fan, 0, 0)]
        + [g.edge(frame_fan, img_pipes[n], n, 0) for n in std.range(0, nanode - 1)]
        + [g.edge(img_pipes[n], clus_pipes[n], 0, 0) for n in std.range(0, nanode - 1)]
        + [g.edge(img_pipes[n], clus_pipes[n], 1, 1) for n in std.range(0, nanode - 1)]
        + [g.edge(clus_pipes[n], flash_attach[n], 0, 0) for n in std.range(0, nanode - 1)]
        + [g.edge(wcls_input.opflashes[n], flash_attach[n], 0, 1) for n in std.range(0, nanode - 1)]
        + [g.edge(flash_attach[n], matching_joint, 0, n) for n in std.range(0, nanode - 1)]
        + [g.edge(matching_joint, clus_all_apa, 0, 0)]
        + [g.edge(clus_all_apa, pr_node, 0, 0)]
        + [g.edge(pr_node, labeler, 0, 0)]
        + [g.edge(labeler, cfd_terminal, 0, 0)]
);

local app = {
  type: 'Pgrapher',
  data: { edges: g.edges(graph) },
};

local cmdline = {
    type: "wire-cell",
    data: {
        plugins: ["WireCellGen", "WireCellPgraph", "WireCellAux", "WireCellSio",
                  "WireCellSigProc", "WireCellImg", "WireCellRoot", "WireCellTbb",
                  "WireCellClus", "WireCellMatch"],
        apps: ["Pgrapher"]
    }
};

[cmdline] + g.uses(graph) + cathode_fv.configs + [app]
