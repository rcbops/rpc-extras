#!/bin/bash

## Shell Opts ----------------------------------------------------------------

set -euv
set -o pipefail

## Vars ----------------------------------------------------------------------

# These vars are set by the CI environment, but are given defaults
# here to cater for situations where someone is executing the test
# outside of the CI environment.
export RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"

## Functions -----------------------------------------------------------------
source ../../scripts/functions.sh

## Main ----------------------------------------------------------------------

# Copy the tempest results to the job results folder
mkdir -p ${RE_HOOK_RESULT_DIR}

# Copy the job artifacts to the job artifacts folder
export RSYNC_CMD="rsync --archive --safe-links --ignore-errors --quiet --no-perms --no-owner --no-group"
export RSYNC_ETC_CMD="${RSYNC_CMD} --no-links --exclude selinux/"

echo "#### BEGIN LOG COLLECTION ###"
mkdir -vp \
    "${RE_HOOK_ARTIFACT_DIR}/logs/host" \
    "${RE_HOOK_ARTIFACT_DIR}/logs/openstack" \
    "${RE_HOOK_ARTIFACT_DIR}/etc/host" \
    "${RE_HOOK_ARTIFACT_DIR}/etc/openstack" \
    "${RE_HOOK_ARTIFACT_DIR}/kibana"

# Copy the host and container log files
${RSYNC_CMD} /var/log/ "${RE_HOOK_ARTIFACT_DIR}/logs/host" || true
if [ -d "/openstack/log" ]; then
  ${RSYNC_CMD} /openstack/log/ "${RE_HOOK_ARTIFACT_DIR}/logs/openstack" || true
fi

# Copy the host /etc directory
${RSYNC_ETC_CMD} /etc/ "${RE_HOOK_ARTIFACT_DIR}/etc/host/" || true

# Loop over each container and archive its /etc directory
if which lxc-ls &> /dev/null; then
  for CONTAINER_NAME in `lxc-ls -1`; do
    CONTAINER_PID=$(lxc-info -p -n ${CONTAINER_NAME} | awk '{print $2}')
    CONTAINER_ROOT_DIR="/proc/${CONTAINER_PID}/root/"
    CONTAINER_ETC_DIR="${CONTAINER_ROOT_DIR}/etc/"
    if echo ${CONTAINER_NAME} | grep "utility"; then
      find "${CONTAINER_ROOT_DIR}" -type f -name 'tempest_results.xml' -exec cp {} ${RE_HOOK_RESULT_DIR}/ \;
    fi
    ${RSYNC_ETC_CMD} ${CONTAINER_ETC_DIR} "${RE_HOOK_ARTIFACT_DIR}/etc/openstack/${CONTAINER_NAME}/" || true
  done
fi
echo "#### END LOG COLLECTION ###"

# Only enable snapshot when triggered by a commit push.
# This is to enable image updates whenever a PR is merged, but not before
if [[ "${RE_JOB_TRIGGER:-USER}" == "PUSH" ]]; then
  echo "### BEGIN SNAPSHOT PREP ###"
  mkdir -p /gating/thaw

  # /opt/rpc-openstack may be a symlink to $WORKSPACE/rpc-openstack
  # However $WORKSPACE will be wiped prior to the snapshot being taken
  # so will not be present in instances created from the snapshot.
  # In order to ensure /opt/rpc-openstack is present in the snapshot
  # We check if its a link if it is, unlink it and create a full copy.
  pushd /opt
  target="$(readlink -f rpc-openstack)"
  if [[ -n "$target" ]]; then
      echo "/opt/rpc-openstack is linked into $WORKSPACE/rpc-openstack which"
      echo "will be wiped prior to creating a snapshot."
      echo "Removing symlink and copying $WORKSPACE/rpc-openstack to /opt."
      rm rpc-openstack
      cp -ar $target rpc-openstack
  fi

  # /root/.ssh is cleared on thaw. We need to store the keys that were there.
  mkdir -p /opt/root_ssh_backup
  cp -vr /root/.ssh /opt/root_ssh_backup

  ln -s /opt/rpc-openstack/gating/thaw/run /gating/thaw/run

  distro="$(lsb_release --codename --short)"

  echo "rpc_${RPC_RELEASE}_${distro}" > /gating/thaw/image_name
  echo "### END SNAPSHOT PREP ###"
fi
