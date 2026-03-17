#!/usr/bin/env bash
set -euo pipefail

# Lines 4-8: inputs
# MG_CARD, NEVENTS, LHE_OUT, optional RUN_NAME, optional config file.
MG_CARD="${1:?Usage: run_madgraph.sh <mg5_card> <nevents> <lhe_out> [run_name] [config_file]}"
NEVENTS="${2:-10000}"
LHE_OUT="${3:-/data/events_mg.lhe}"
RUN_NAME="${4:-run_01}"
RUN_CARD_CONFIG="${5:-}"

# Lines 10-23: discover paths
# It extracts the process directory from the output line in the MG card,
# and if no config file is passed, it auto-looks for a matching .cfg.
PROCESS_DIR="$(awk '$1 == "output" {print $2}' "${MG_CARD}" | tail -n 1)"
if [[ -z "${PROCESS_DIR}" ]]; then
  echo "Could not determine MadGraph output directory from ${MG_CARD}" >&2
  exit 1
fi

if [[ -z "${RUN_CARD_CONFIG}" ]]; then
  CARD_DIR="$(dirname "${MG_CARD}")"
  CARD_BASE="$(basename "${MG_CARD}" .txt)"
  INFERRED_CONFIG="${CARD_DIR}/${CARD_BASE}.cfg"
  if [[ -f "${INFERRED_CONFIG}" ]]; then
    RUN_CARD_CONFIG="${INFERRED_CONFIG}"
  fi
fi

# Lines 25-34: create the MG process directory
# It prints what it will do, clears any old process directory,
# and runs mg5_aMC on the card.
echo "[MadGraph] Process card : ${MG_CARD}"
echo "[MadGraph] Output dir   : ${PROCESS_DIR}"
echo "[MadGraph] Events       : ${NEVENTS}"
if [[ -n "${RUN_CARD_CONFIG}" ]]; then
  echo "[MadGraph] Run config   : ${RUN_CARD_CONFIG}"
fi

mkdir -p "$(dirname "${LHE_OUT}")"
rm -rf "${PROCESS_DIR}"
/opt/MG5_aMC/bin/mg5_aMC "${MG_CARD}"

# Lines 36-40: find run_card.dat
# MadGraph creates this file inside the generated process directory.
RUN_CARD="${PROCESS_DIR}/Cards/run_card.dat"
if [[ ! -f "${RUN_CARD}" ]]; then
  echo "MadGraph run card not found: ${RUN_CARD}" >&2
  exit 1
fi

# Lines 42-55: helper for editing one run-card parameter
# This is just a small local function to replace values like
# nevents, mmll, mmllmax.
set_run_card_value() {
  local key="$1"
  local value="$2"

  if grep -Eq "^[[:space:]]*[-+0-9.eE]+[[:space:]]*= ${key}\b" "${RUN_CARD}"; then
    sed -i -E "s|^[[:space:]]*[-+0-9.eE]+[[:space:]]*= ${key}\b| ${value} = ${key}|" "${RUN_CARD}"
    return 0
  fi

  echo "MadGraph run card setting not found: ${key}" >&2
  exit 1
}

# Lines 55-75: apply settings
# It always sets nevents, then reads any optional key = value pairs
# from the .cfg file, like sim/MG_cards/madgraph_proc_Zmumu_ffbar.cfg.
set_run_card_value "nevents" "${NEVENTS}"

if [[ -n "${RUN_CARD_CONFIG}" ]]; then
  if [[ ! -f "${RUN_CARD_CONFIG}" ]]; then
    echo "MadGraph config file not found: ${RUN_CARD_CONFIG}" >&2
    exit 1
  fi

  while IFS='=' read -r key value; do
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ -z "${key}" || "${key}" == \#* ]]; then
      continue
    fi

    set_run_card_value "${key}" "${value}"
  done < "${RUN_CARD_CONFIG}"
fi

# Lines 77-91: generate events and export the LHE
# It runs MadGraph event generation, then either decompresses
# unweighted_events.lhe.gz or copies unweighted_events.lhe
# to your requested output path.
"${PROCESS_DIR}/bin/generate_events" "${RUN_NAME}" -f

LHE_GZ="${PROCESS_DIR}/Events/${RUN_NAME}/unweighted_events.lhe.gz"
LHE_PLAIN="${PROCESS_DIR}/Events/${RUN_NAME}/unweighted_events.lhe"

if [[ -f "${LHE_GZ}" ]]; then
  gzip -dc "${LHE_GZ}" > "${LHE_OUT}"
elif [[ -f "${LHE_PLAIN}" ]]; then
  cp "${LHE_PLAIN}" "${LHE_OUT}"
else
  echo "MadGraph did not produce an LHE file in ${PROCESS_DIR}/Events/${RUN_NAME}" >&2
  exit 1
fi

echo "[MadGraph] LHE file     : ${LHE_OUT}"
