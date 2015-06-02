#!/usr/bin/env bash
# Copyright 2014, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# (c) 2015, Nolan Brubaker <nolan.brubaker@rackspace.com>
set -e -u -x
set -o pipefail

OSAD_DIR='/opt/rpc-extras/os-ansible-deployment'
RPCD_DIR='/opt/rpc-extras/rpcd'

export RPC_CONFIG_FILE=${RPC_CONFIG_FILE:-"/etc/rpc_deploy/rpc_user_config.yml"}

if [[ -f "${RPC_CONFIG_FILE}" && ! -z $(grep -Rq openstack_repo_url "${RPC_CONFIG_FILE}") ]]; then
    # repo containers will be made automatically, but we add the openstack_repo_url variable
    # so that the first repo container will be used, rather than the load balancer's IP.
    # This simplifies our upgrade logic, since we don't have to generate a temporary inventory.
    echo "openstack_repo_url: \"http://{{ groups['infra_hosts'][0].ip }}:{{ repo_server_port }}\"" >> "${RPC_CONFIG_FILE}"
fi

# Do the actual upgrade
cd /opt/rpc-extras/os-ansible-deployment
/opt/rpc-extras/os-ansible-deployment/scripts/run-upgrade.sh

# install RPC-specific stuff
source /opt/rpc-extras/os-ansible-deployment/scripts/scripts-library.sh
cd "${RPCD_DIR}"/playbooks/

# TODO(nolan) need to remove the stuff in the maas directory. Maybe make a
# play for upgrade-maas?

install_bits horizon_extensions.yml rpc-support.yml setup-maas.yml
