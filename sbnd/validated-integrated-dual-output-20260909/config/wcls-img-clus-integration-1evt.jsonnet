// Integration-specific entry config for the 1-event integration validation.
//
// Derived from:
//   wcp-porting/sbnd/wcls-img-clus-matching-xin.jsonnet
//   validated at checkpoint/validated-dual-output-2026-09-08 (b949ae9e)
//
// CHANGES vs validated config:
//   1. iso_endpoint=true REMOVED — parameter was dropped in Haiwang's
//      integration WCT (b2e3c6a9).  Removal is the only API incompatibility
//      between validated (bc7f4af9) and integration clus.jsonnet.
//   2. Output filename changed: reco_wirecell_50evt.root → (set via FCL)
//   3. HDF5 filename changed to nugraph.h5 (default, unchanged)
//
// This file is placed in one-event-test/config/ and put FIRST on
// WIRECELL_PATH so it shadows the wcp-porting/sbnd copy.  All other imports
// resolve from the integration WCT cfg tree (b2e3c6a9).

local g = import "pgraph.jsonnet";
local wc = import "wirecell.jsonnet";

local tools_maker = import 'pgrapher/common/tools.jsonnet';

local reality = std.extVar('reality');

local params = import 'pgrapher/experiment/sbnd/simparams.jsonnet';

local tools_all = tools_maker(params);
local tools = tools_all {anodes: [tools_all.anodes[n] for n in [0, 1]]};
local nanode = std.length(tools.anodes);

// ---- artROOT inputs (must match the names used in the fcl inputers) ----
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

local img = import 'pgrapher/experiment/sbnd/img.jsonnet';
local img_maker = img();
local img_pipes = [
    img_maker.per_anode(tools.anodes[n], 'multi-3view', add_dump=false, full_deghost=true)
    for n in std.range(0, nanode - 1)
];

local clus = import 'pgrapher/experiment/sbnd/clus.jsonnet';
local clus_maker = clus(rse_from_ident=true, reality=reality);

local bee_shared = {
    type: 'BeeSink',
    name: 'mabc_shared',
    data: { outname: 'mabc.zip', initial_index: 0 },
};

local clus_pipes = [
    clus_maker.per_apa(tools.anodes[n], dump=false, bee_sink=bee_shared, save_assoc_id=true)
    for n in std.range(0, nanode - 1)
];

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
                                        bee_sink=bee_shared, premerged=true,
                                        save_real_cluster_id=true,
                                        save_assoc_cluster_id=true);

local beam_window = [0.2 * wc.us, 2.2 * wc.us];

local pds = (import 'pgrapher/experiment/sbnd/particle_dataset.jsonnet')();
// INTEGRATION CHANGE: iso_endpoint removed (dropped in b2e3c6a9 integration WCT).
// stamp_matching_bundle_id=true: preserved — required for NuGraph4 provenance.
local pr_node = clus_maker.pr(
    tools.anodes, dump=false,
    pipeline_names=['switch_scope', 'unmerge_bundle', 'unmerge_assoc', 'steiner',
                    'fiducialutils', 'tagger_check_tgm', 'tagger_check_stm', 'tagger_check_fc'],
    particle_dataset=pds.particle_dataset, extra_uses=pds.all, beam_window=beam_window,
    stamp_matching_bundle_id=true);

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
        bee_sink: wc.tn(bee_shared),
        tagger_coords: clus_maker.bee_coords,
        beam_window: beam_window,
    },
}, nin=1, nout=1,
   uses=tools.anodes + [lbl_dv, lbl_pcts, clus_maker.sce_field_fwd, lbl_fv, bee_shared]);

local tail_dump = g.pnode({
    type: 'TensorFileSink',
    name: 'clus_all_apa',
    data: {
        outname: 'trash-all-apa.tar.gz',
        prefix: 'clustering_',
        dump_mode: false,
    },
}, nin=1, nout=0);

local graph = g.intern(
    innodes=[wcls_input.sigs],
    centernodes=[frame_fan] + img_pipes + clus_pipes + flash_attach
                + [matching_joint] + wcls_input.opflashes
                + [clus_all_apa, pr_node, labeler],
    outnodes=[tail_dump],
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
        + [g.edge(labeler, tail_dump, 0, 0)]
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
