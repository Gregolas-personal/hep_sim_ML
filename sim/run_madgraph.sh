#!/usr/bin/env bash
set -euo pipefail

# Usage:
# run_madgraph.sh <mg5_card> <nevents> <lhe_out> [run_name] [run_card_cfg] [param_card_template]

MG_CARD="${1:?Usage: run_madgraph.sh <mg5_card> <nevents> <lhe_out> [run_name] [run_card_cfg] [param_card_template]}"
NEVENTS="${2:-10000}"
LHE_OUT="${3:-/data/events_mg.lhe}"
RUN_NAME="${4:-run_01}"
RUN_CARD_CONFIG="${5:-}"
PARAM_CARD_TEMPLATE="${6:-}"

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

echo "[MadGraph] Process card : ${MG_CARD}"
echo "[MadGraph] Output dir   : ${PROCESS_DIR}"
echo "[MadGraph] Events       : ${NEVENTS}"
if [[ -n "${RUN_CARD_CONFIG}" ]]; then
  echo "[MadGraph] Run config   : ${RUN_CARD_CONFIG}"
fi
if [[ -n "${PARAM_CARD_TEMPLATE}" ]]; then
  echo "[MadGraph] Param card   : ${PARAM_CARD_TEMPLATE}"
fi

mkdir -p "$(dirname "${LHE_OUT}")"
rm -rf "${PROCESS_DIR}"
/opt/MG5_aMC/bin/mg5_aMC "${MG_CARD}"

RUN_CARD="${PROCESS_DIR}/Cards/run_card.dat"
if [[ ! -f "${RUN_CARD}" ]]; then
  echo "MadGraph run card not found: ${RUN_CARD}" >&2
  exit 1
fi

PARAM_CARD="${PROCESS_DIR}/Cards/param_card.dat"
merge_param_card_overrides() {
  local base_card="$1"
  local override_card="$2"
  local tmp_card
  tmp_card="$(mktemp)"

  awk '
  function trim(s) {
    gsub(/^[ \t]+/, "", s)
    gsub(/[ \t]+$/, "", s)
    return s
  }
  function decomment(s) {
    sub(/[ \t]*#.*/, "", s)
    return trim(s)
  }
  FNR==NR {
    raw=$0
    sub(/\r$/, "", raw)
    line=trim(raw)
    if (line=="" || line ~ /^#/) next

    upper=toupper(line)
    if (upper ~ /^BLOCK[ \t]+MASS([ \t]|$)/) {
      in_mass_override=1
      next
    }
    if (upper ~ /^BLOCK[ \t]+/) {
      in_mass_override=0
      next
    }
    if (upper ~ /^DECAY[ \t]+/) {
      clean=decomment(raw)
      n=split(clean, a, /[ \t]+/)
      if (n >= 3 && a[2] ~ /^[-+]?[0-9]+$/) {
        decay_line[a[2]]=raw
      }
      next
    }
    if (in_mass_override) {
      clean=decomment(raw)
      n=split(clean, a, /[ \t]+/)
      if (n >= 2 && a[1] ~ /^[-+]?[0-9]+$/) {
        mass_line[a[1]]=raw
      }
    }
    next
  }
  {
    raw=$0
    sub(/\r$/, "", raw)
    line=trim(raw)
    upper=toupper(line)

    if (upper ~ /^BLOCK[ \t]+MASS([ \t]|$)/) {
      saw_mass_block=1
      in_mass=1
      print raw
      next
    }

    if (in_mass && upper ~ /^BLOCK[ \t]+/ && upper !~ /^BLOCK[ \t]+MASS([ \t]|$)/) {
      for (id in mass_line) {
        if (!(id in mass_done)) {
          print mass_line[id]
          mass_done[id]=1
        }
      }
      in_mass=0
      print raw
      next
    }

    if (in_mass) {
      clean=decomment(raw)
      n=split(clean, a, /[ \t]+/)
      if (n >= 1 && a[1] ~ /^[-+]?[0-9]+$/ && (a[1] in mass_line)) {
        print mass_line[a[1]]
        mass_done[a[1]]=1
        next
      }
      print raw
      next
    }

    if (upper ~ /^DECAY[ \t]+/) {
      clean=decomment(raw)
      n=split(clean, a, /[ \t]+/)
      if (n >= 3 && a[2] ~ /^[-+]?[0-9]+$/ && (a[2] in decay_line)) {
        print decay_line[a[2]]
        decay_done[a[2]]=1
        next
      }
    }

    print raw
  }
  END {
    if (in_mass) {
      for (id in mass_line) {
        if (!(id in mass_done)) {
          print mass_line[id]
          mass_done[id]=1
        }
      }
    }

    if (!saw_mass_block) {
      if (length(mass_line) > 0) {
        print "Block MASS"
        for (id in mass_line) {
          if (!(id in mass_done)) {
            print mass_line[id]
            mass_done[id]=1
          }
        }
      }
    }

    for (id in decay_line) {
      if (!(id in decay_done)) {
        print decay_line[id]
      }
    }
  }
  ' "${override_card}" "${base_card}" > "${tmp_card}"

  mv "${tmp_card}" "${base_card}"
}

if [[ -n "${PARAM_CARD_TEMPLATE}" ]]; then
  if [[ ! -f "${PARAM_CARD_TEMPLATE}" ]]; then
    echo "MadGraph param card template not found: ${PARAM_CARD_TEMPLATE}" >&2
    exit 1
  fi
  merge_param_card_overrides "${PARAM_CARD}" "${PARAM_CARD_TEMPLATE}"
fi

set_run_card_value() {
  local key="$1"
  local value="$2"
  local required="${3:-false}"

  if grep -Eq "^[[:space:]]*[^#]+=[[:space:]]*${key}\b" "${RUN_CARD}"; then
    sed -i -E "s|^[[:space:]]*[^#]+=[[:space:]]*${key}\b| ${value} = ${key}|" "${RUN_CARD}"
    return 0
  fi

  if [[ "${required}" == "true" ]]; then
    echo "MadGraph run card setting not found: ${key}" >&2
    exit 1
  fi

  echo "MadGraph run card setting not found, skipping optional override: ${key}" >&2
  return 0
}

set_run_card_value "nevents" "${NEVENTS}" "true"

if [[ -n "${RUN_CARD_CONFIG}" ]]; then
  if [[ ! -f "${RUN_CARD_CONFIG}" ]]; then
    echo "MadGraph config file not found: ${RUN_CARD_CONFIG}" >&2
    exit 1
  fi

  while IFS='=' read -r key value; do
    key="${key//$'\r'/}"
    value="${value//$'\r'/}"
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
