#!/usr/bin/env bash
#
# Copyright 2014-2016, Rackspace US, Inc.
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

set -eux -o pipefail

BASE_DIR=$( cd "$( dirname ${0} )" && cd ../ && pwd )
OA_DIR="$BASE_DIR/openstack-ansible"
RPCD_DIR="$BASE_DIR/rpcd"

# One of the first things we need to do is update our /etc/openstack_deploy variables, which requires running
# migrate-yaml.py.  Unfortunately, this needs the deepdiff python module which we don't have in our repo server.
rm -rf /root/.pip

# Create a backup of /etc/openstack_deploy, if one doesn't already exist
# NOTE: This gets done by openstack-ansible's scripts/run-upgrade.sh script, but if we wait until then
#       it'll be too late.
if [ ! -d "/etc/openstack_deploy.MITAKA" ]; then
    cp -a /etc/openstack_deploy /etc/openstack_deploy.MITAKA
fi

# Merge files
pip install deepdiff
${BASE_DIR}/scripts/migrate-yaml.py --overrides /etc/openstack_deploy/user_variables.yml \
                                    --danger-mode DANGER > /etc/openstack_deploy/user_osa_variables_overrides.yml
${BASE_DIR}/scripts/migrate-yaml.py --overrides /etc/openstack_deploy/user_extras_variables.yml \
                                    --danger-mode DANGER > /etc/openstack_deploy/user_rpco_variables_overrides.yml
cp -a ${RPCD_DIR}/etc/openstack_deploy/*defaults* /etc/openstack_deploy
rm /etc/openstack_deploy/{user_variables,user_extras_variables}.yml

# Update ansible
# NOTE: This gets run again in openstack-ansible's scripts/run-upgrade.sh
#       script, is there a way we can avoid it running 2x?
cd ${OA_DIR}
bash scripts/bootstrap-ansible.sh

# Update rpc-openstack galaxy modules
ansible-galaxy install --role-file=${BASE_DIR}/ansible-role-requirements.yml --force \
                       --roles-path=${RPCD_DIR}/playbooks/roles

# TBD if this is 100% necessary
cd ${RPCD_DIR}/playbooks
openstack-ansible pip-lockdown.yml

# The repo-install.yml playbook will fail if this is not done
ansible -m shell -a 'rm -rf /var/www/repo/openstackgit/horizon-extensions' repo_all

# NOTE: We're not updating any ceph roles / releases in this upgrade, so we won't
#       re-run the ceph playbooks.  Is there any reason why we should?

# Upgrade openstack-ansible
cd ${OA_DIR}
export I_REALLY_KNOW_WHAT_I_AM_DOING=true
echo "YES" | ${OA_DIR}/scripts/run-upgrade.sh

# Finish off rpc-openstack upgrade
# NOTE: In liberty this simply called scripts/deploy.sh with DEPLOY_OA="no",
#       which way should we be doing this?
cd ${RPCD_DIR}/playbooks
openstack-ansible site.yml
