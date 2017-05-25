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

echo "POST LEAP STEPS"
if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/deploy-rpc.complete" ]]; then
  pushd ${RPCO_DEFAULT_FOLDER}/rpcd/playbooks/
    unset ANSIBLE_INVENTORY
    sed -i 's#export ANSIBLE_INVENTORY=.*#export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-/opt/rpc-openstack/openstack-ansible/playbooks/inventory}"#g' /usr/local/bin/openstack-ansible.rc
    openstack-ansible setup-logging.yml
    openstack-ansible setup-maas.yml
    # TODO(add support role)
  popd
  log "deploy-rpc" "ok"
else
  log "deploy-rpc" "skipped"
fi
