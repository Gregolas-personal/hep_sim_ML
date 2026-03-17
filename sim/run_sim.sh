#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_sim.sh
  run_sim.sh pythia [cmnd_file] [nevents] [hepmc_out] [root_out] [delphes_card]
  run_sim.sh madgraph [mg5_card] [pythia_cmnd] [nevents] [lhe_out] [hepmc_out] [root_out] [delphes_card]

Notes:
  - Calling run_sim.sh with no mode keeps the original PYTHIA -> Delphes workflow.
  - MadGraph mode runs MG5_aMC -> LHE -> PYTHIA shower/hadronization -> HepMC3 -> Delphes.
EOF
}

run_delphes() {
  local card="$1"
  local root_out="$2"
  local hepmc_out="$3"

  echo "[Delphes] Running detector simulation"
  source /opt/root/bin/thisroot.sh
  export ROOT_INCLUDE_PATH="/opt/Delphes:/opt/Delphes/classes:/opt/Delphes/external:${ROOT_INCLUDE_PATH:-}"
  /opt/Delphes/DelphesHepMC3 "${card}" "${root_out}" "${hepmc_out}"
}

mkdir -p /data

MODE="${1:-pythia}"
if [[ "${MODE}" == "-h" || "${MODE}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${MODE}" != "pythia" && "${MODE}" != "madgraph" ]]; then
  set -- pythia "$@"
  MODE="pythia"
fi

if [[ "${MODE}" == "pythia" ]]; then
  shift || true
  CMND_FILE="${1:-/workspace/PYTHIA_cards/pythia_cmnd_Zmumu.txt}"
  NEVENTS="${2:-10000}"
  HEPMC_OUT="${3:-/data/events.hepmc}"
  ROOT_OUT="${4:-/data/delphes_output.root}"
  CARD="${5:-/workspace/cards/delphes_card_ATLAS.tcl}"

  echo "[1/2] Generating HepMC3 events with PYTHIA"
  /workspace/pythia_to_hepmc3 "${CMND_FILE}" "${HEPMC_OUT}" "${NEVENTS}"

  echo "[2/2] Running Delphes"
  run_delphes "${CARD}" "${ROOT_OUT}" "${HEPMC_OUT}"

  echo "Done"
  echo "Mode        : pythia"
  echo "Command file: ${CMND_FILE}"
  echo "HepMC file  : ${HEPMC_OUT}"
  echo "ROOT file   : ${ROOT_OUT}"
  exit 0
fi

shift
MG_CARD="${1:-/workspace/MG_cards/madgraph_proc_ZH_ffbar.txt}"
PYTHIA_CMND="${2:-/workspace/PYTHIA_cards/pythia_cmnd_lhef.txt}"
NEVENTS="${3:-10000}"
LHE_OUT="${4:-/data/events_mg.lhe}"
HEPMC_OUT="${5:-/data/events_mg.hepmc}"
ROOT_OUT="${6:-/data/delphes_mg_output.root}"
CARD="${7:-/workspace/cards/delphes_card_ATLAS.tcl}"

echo "[1/3] Generating parton-level events with MadGraph"
/workspace/run_madgraph.sh "${MG_CARD}" "${NEVENTS}" "${LHE_OUT}"

echo "[2/3] Showering and hadronizing LHE events with PYTHIA"
/workspace/pythia_to_hepmc3 "${PYTHIA_CMND}" "${HEPMC_OUT}" "${NEVENTS}" "${LHE_OUT}"

echo "[3/3] Running Delphes"
run_delphes "${CARD}" "${ROOT_OUT}" "${HEPMC_OUT}"

echo "Done"
echo "Mode            : madgraph"
echo "MadGraph card   : ${MG_CARD}"
echo "Pythia card     : ${PYTHIA_CMND}"
echo "LHE file        : ${LHE_OUT}"
echo "HepMC file      : ${HEPMC_OUT}"
echo "ROOT file       : ${ROOT_OUT}"
