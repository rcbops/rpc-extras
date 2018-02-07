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
source $(dirname ${0})/../../scripts/functions.sh

## Main ----------------------------------------------------------------------

echo "#### BEGIN LOG COLLECTION ###"

collect_logs_cmd="ansible-playbook"
collect_logs_cmd+=" --ssh-common-args='-o StrictHostKeyChecking=no'"
collect_logs_cmd+=" --extra-vars='artifacts_dir=${RE_HOOK_ARTIFACT_DIR}'"
collect_logs_cmd+=" --extra-vars='result_dir=${RE_HOOK_RESULT_DIR}'"

if [[ $RE_JOB_IMAGE =~ .*mnaio.* ]]; then
  collect_logs_cmd+=" --extra-vars='target_hosts=pxe_servers'"
  collect_logs_cmd+=" --inventory='/opt/openstack-ansible-ops/multi-node-aio/playbooks/inventory/hosts'"
else
  collect_logs_cmd+=" --extra-vars='target_hosts=localhost'"
fi

collect_logs_cmd+=" $(dirname ${0})/collect_logs.yml"

eval $collect_logs_cmd || true

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
