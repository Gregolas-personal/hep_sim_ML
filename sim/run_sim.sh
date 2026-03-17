#!/usr/bin/env bash
set -euo pipefail

CMND_FILE="${1:-/workspace/pythia_cmnd_Zmumu.txt}"
NEVENTS="${2:-10000}"
HEPMC_OUT="${3:-/data/events.hepmc}"
ROOT_OUT="${4:-/data/delphes_output.root}"
CARD="${5:-/workspace/cards/delphes_card_ATLAS.tcl}"

mkdir -p /data

echo "[1/2] Generating HepMC3 events with PYTHIA"
/workspace/pythia_to_hepmc3 "${CMND_FILE}" "${HEPMC_OUT}" "${NEVENTS}"

echo "[2/2] Running Delphes"
source /opt/root/bin/thisroot.sh
export ROOT_INCLUDE_PATH="/opt/Delphes:/opt/Delphes/classes:/opt/Delphes/external:${ROOT_INCLUDE_PATH:-}"
/opt/Delphes/DelphesHepMC3 "${CARD}" "${ROOT_OUT}" "${HEPMC_OUT}"

echo "Done"
echo "Command file: ${CMND_FILE}"
echo "HepMC file  : ${HEPMC_OUT}"
echo "ROOT file   : ${ROOT_OUT}"
