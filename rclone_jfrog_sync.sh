#!/bin/bash

set -euo pipefail

LOGFILE="/var/log/rclone/rclone.log"
SCRIPTLOG=${LOGFILE}

AGUMBE_CANDIDATE=("FTC_Artifactory_Agumbe_Candidate_Builds" "agumbe-5.1.0/candidate/builds" "")
AGUMBE_STAGING=("FTC_Artifactory_Agumbe_Staging_Builds" "agumbe-5.1.0/staging/builds" "")
SO_GEN5_CANDIDATE=("FTC_Artifactory_SO_Gen5_Candidate_Builds" "so-gen5/candidate/builds" "5.3*/**")
SO_GEN5_STAGING=("FTC_Artifactory_SO_Gen5_Staging_Builds" "so-gen5/staging/builds" "5.3*/**")
SO_GEN5_PRE_RELEASE=("FTC_Artifactory_SO_Gen5_Pre-Releases" "so-gen5/pre-releases" "")
CORGI_9_CANDIDATE=("FTC_Artifactory_Corgi_4.3.9_Candidate_Builds" "corgi-4.3.9/candidate/builds" "4.3.9*/**")
CORGI_11_CANDIDATE=("FTC_Artifactory_Corgi_4.3.11_Candidate_Builds" "corgi-4.3.11/candidate/builds" "4.3.11*/**")
CORGI_13_CANDIDATE=("FTC_Artifactory_Corgi_4.3.13_Candidate_Builds" "corgi-4.3.13/candidate/builds" "3.3.13*/**")
BADAMI_CANDIDATE=("FTC_Artifactory_Badami_Candidate_Builds" "badami-5.2.0/candidate/builds" "5.2*/**")
COORG_53_CANDIDATE=("FTC_Artifactory_Coorg_5.3.0_Candidate_Builds" "coorg-5.3.0/candidate/builds" "5.3.0*/**")
COORG_53_STAGING=("FTC_Artifactory_Coorg_5.3.0_Staging_Builds" "coorg-5.3.0/staging/builds" "5.3.0*/**")
COORG_53_PRE_RELEASE=("FTC_Artifactory_Coorg_5.3.0_Pre-Releases" "coorg-5.3.0/pre-releases" "5.3.0*/**")
SO_GEN54_STAGING=("FTC_Artifactory_SO_Gen5_Staging_Builds" "so-gen5/staging/builds" "5.4*/**")

# --include "5.3*/**"

BUILDS=("SO_GEN54_STAGING" "COORG_53_PRE_RELEASE" "COORG_53_STAGING" "COORG_53_CANDIDATE" "CORGI_13_CANDIDATE" "AGUMBE_CANDIDATE" "AGUMBE_STAGING" "CORGI_9_CANDIDATE" "CORGI_11_CANDIDATE" "SO_GEN5_CANDIDATE" "SO_GEN5_STAGING" "BADAMI_CANDIDATE")
##### BUILDS=("SO_GEN54_STAGING")

# Trap for unexpected exits
trap 'on_error $LINENO $?' ERR

on_error() {
  local lineno=$1
  local code=$2
  echo "ERROR: Script failed at line $lineno with exit code $code" >> "${SCRIPTLOG}"
  echo "==== ERROR ==== $(date) ====" >> "${LOGFILE}"
  exit $code
}

log_rc() {
  local rc="$1"

  if [ "$rc" -ne 0 ]; then
    echo "[$(date)] ERROR: rclone failed with exit code $rc" >> "${SCRIPTLOG}"
  else
    echo "[$(date)] INFO: rclone completed successfully (exit 0)." >> "${SCRIPTLOG}"
  fi
}

call_rclone() {
  local REPO="$1"
  local DIR="$2"
  local INCLUDE="${3:-}"

  # Build rclone command as array (safe)
  local CMD=(/usr/bin/rclone sync "${REPO}:" "/repo_mirror/${DIR}"
    --no-check-certificate
    --transfers=12
    --multi-thread-streams 12
#    --multi-thread-chunk-size 500M
    --multi-thread-cutoff 500M
    --check-first
    --metadata
    --use-server-modtime
    --log-level=DEBUG
    --stats-one-line
    --retries=6
    --low-level-retries=10
    --timeout=10m
    --stats=30s
    --log-file="${LOGFILE}"
  )

  # Add include filter if provided
  if [[ -n "${INCLUDE}" ]]; then
    CMD+=(--include "${INCLUDE}")
  fi

  # Execute command
  "${CMD[@]}"
  RC=$?
  return ${RC}
}

echo -e "==== BEGIN ==== $(date) ==== BEGIN ====\n" >> "${LOGFILE}"

for BUILD in "${BUILDS[@]}"; do
  # Create a nameref 'ref' to the array named by $name
  declare -n ref="$BUILD"

  echo "[$(date)] Starting rclone sync ${ref[0]} ..." >> "${SCRIPTLOG}"

  call_rclone "${ref[0]}" "${ref[1]}" "${ref[2]}"
  rc=$?

  log_rc "${rc}"
done

echo -e "==== END ==== $(date) ==== END ====" >> "${LOGFILE}"
