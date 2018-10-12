#!/usr/bin/env bash

# Copyright 2017, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Shell Opts ----------------------------------------------------------------

set -exu

echo "Preparing a Multi Node AIO (MNAIO)"

## Vars and Functions --------------------------------------------------------

source "$(readlink -f $(dirname ${0}))/../gating_vars.sh"

source /opt/rpc-openstack/scripts/functions.sh

source "$(readlink -f $(dirname ${0}))/../mnaio_vars.sh"

## Main ----------------------------------------------------------------------

# checkout openstack-ansible-ops
if [ ! -d "/opt/openstack-ansible-ops" ]; then
  git clone --recursive https://github.com/openstack/openstack-ansible-ops /opt/openstack-ansible-ops
else
  pushd /opt/openstack-ansible-ops
    git fetch --all
  popd
fi

# build the multi node aio
pushd /opt/openstack-ansible-ops/multi-node-aio
  # Prepare the multi node aio host
  # Note (odyssey4me):
  # We cannot use build.sh here because the playbook imports
  # result in running all plays with all tasks having a conditional
  # set on them, and because the VM's aren't running at this stage
  # the plays fail. This is a workaround until there are upstream
  # improvements to counteract that issue.
  source bootstrap.sh
  source ansible-env.rc
  [[ "${SETUP_HOST}" == "true" ]] && run_mnaio_playbook playbooks/setup-host.yml
  [[ "${SETUP_PXEBOOT}" == "true" ]] && run_mnaio_playbook playbooks/deploy-acng.yml
  [[ "${SETUP_PXEBOOT}" == "true" ]] && run_mnaio_playbook playbooks/deploy-pxe.yml
  [[ "${SETUP_DHCPD}" == "true" ]] && run_mnaio_playbook playbooks/deploy-dhcp.yml
  [[ "${DEPLOY_VMS}" == "true" ]] && run_mnaio_playbook playbooks/deploy-vms.yml

  # If there are images available, and this is not the 'deploy' action,
  # then we need to download the images, then create the VM's. The conditional
  # was already evaluated in mnaio_vars, so we key off DEPLOY_VMS here.
  if [[ "${DEPLOY_VMS}" == "false" ]]; then
    run_mnaio_playbook playbooks/download-vms.yml -e manifest_url=${RPCO_IMAGE_MANIFEST_URL} -e aria2c_log_path=${RE_HOOK_ARTIFACT_DIR}
    run_mnaio_playbook playbooks/deploy-vms.yml
  fi
popd

echo "Multi Node AIO preparation completed..."
