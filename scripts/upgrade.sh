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
set -eux pipefail

BASE_DIR=$( cd "$( dirname ${0} )" && cd ../ && pwd )
OSAD_DIR="$BASE_DIR/os-ansible-deployment"
RPCD_DIR="$BASE_DIR/rpcd"

# Merge new overrides into existing user_variables before upgrade
# contents of existing user_variables take precedence over new overrides
cp ${RPCD_DIR}/etc/openstack_deploy/user_variables.yml /tmp/upgrade_user_variables.yml
${BASE_DIR}/scripts/update-yaml.py /tmp/upgrade_user_variables.yml /etc/rpc_deploy/user_variables.yml
mv /tmp/upgrade_user_variables.yml /etc/rpc_deploy/user_variables.yml

# Upgrade Ansible in-place so we have access to the patch module.
cd ${OSAD_DIR}
${OSAD_DIR}/scripts/bootstrap-ansible.sh

# Apply any patched files.
cd ${RPCD_DIR}/playbooks
openstack-ansible -i "localhost," patcher.yml

# Do the upgrade for os-ansible-deployment components
cd ${OSAD_DIR}
${OSAD_DIR}/scripts/run-upgrade.sh

# Prevent the deployment script from re-running the OSAD playbooks
export DEPLOY_OSAD="no"

# Do the upgrade for the RPC components
source ${OSAD_DIR}/scripts/scripts-library.sh
cd ${BASE_DIR}
${BASE_DIR}/scripts/deploy.sh

# the auth_ref on disk is now not usable by the new plugins
cd ${RPCD_DIR}/playbooks 
ansible hosts -m shell -a 'rm /root/.auth_ref.json'
