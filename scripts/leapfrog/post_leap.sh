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
#
# (c) 2017, Jean-Philippe Evrard <jean-philippe.evrard@rackspace.co.uk>

## Shell Opts ----------------------------------------------------------------
set -e -u -x
set -o pipefail

export RPCM_VARIABLES=${RPCM_VARIABLES:-/etc/openstack_deploy/user_rpcm_variables.yml}

echo "POST LEAP STEPS"

if [[ ! -f "${RPCM_VARIABLES}" ]]; then
  cp "${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/user_rpcm_variables.yml" "${RPCM_VARIABLES}"
fi

if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/deploy-rpc.complete" ]]; then
  pushd ${RPCO_DEFAULT_FOLDER}/rpcd/playbooks/
    unset ANSIBLE_INVENTORY
    sed -i 's#export ANSIBLE_INVENTORY=.*#export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-/opt/rpc-openstack/openstack-ansible/playbooks/inventory}"#g' /usr/local/bin/openstack-ansible.rc
    sed -i 's#\*"/opt/openstack-ansible"\*#\*"/opt/rpc-openstack/openstack-ansible"\*#' /usr/local/bin/ansible
    # TODO(remove the following hack to restart the neutron agents, when fixed upstream)
    ansible -m shell -a "restart neutron-linuxbridge-agent" nova_compute -i /opt/rpc-openstack/openstack-ansible/playbooks/inventory/dynamic_inventory.py
    openstack-ansible ${RPCO_DEFAULT_FOLDER}/scripts/leapfrog/playbooks/remove-old-agents-from-maas.yml
    . ${RPCO_DEFAULT_FOLDER}/scripts/deploy-rpc-playbooks.sh
  popd
  log "deploy-rpc" "ok"
else
  log "deploy-rpc" "skipped"
fi
echo "LEAPFROG COMPLETE."
