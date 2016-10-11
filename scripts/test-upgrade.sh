#!/usr/bin/env bash
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
# (c) 2016, Matthew Thode <matt.thode@rackspace.com>

set -eux -o pipefail

export BASE_DIR=$( cd "$( dirname ${0} )" && cd ../ && pwd )
export OA_DIR="$BASE_DIR/openstack-ansible"
export RPCD_DIR="$BASE_DIR/rpcd"
export UPGRADE_VARIABLES_FILE="/etc/openstack_deploy/user_upgrade_variables.yml"

source ${BASE_DIR}/scripts/functions.sh

# TASK #0
# Bug: https://github.com/rcbops/u-suk-dev/issues/347
# Issue: Variables files have been reorganized, run a migration script to move
#        them to the new location.
# WARNING: In no way should the migrate-yaml.py script be run with
#          --for-testing-take-new-vars-only in production environments.
if [[ ! -f "/etc/openstack_deploy/user_rpco_variables_overrides.yml" ]]; then
  "${BASE_DIR}"/scripts/migrate-yaml.py --for-testing-take-new-vars-only \
      --defaults "${RPCD_DIR}"/etc/openstack_deploy/user_rpco_variables_defaults.yml \
      --overrides /etc/openstack_deploy/user_extras_variables.yml \
      --output-file /etc/openstack_deploy/user_rpco_variables_overrides.yml
  rm -f /etc/openstack_deploy/user_extras_variables.yml
fi
if [[ ! -f "/etc/openstack_deploy/user_osa_variables_overrides.yml" ]]; then
  "${BASE_DIR}"/scripts/migrate-yaml.py --for-testing-take-new-vars-only \
    --defaults "${RPCD_DIR}"/etc/openstack_deploy/user_osa_variables_defaults.yml \
    --overrides /etc/openstack_deploy/user_variables.yml \
    --output-file /etc/openstack_deploy/user_osa_variables_overrides.yml
  rm -f /etc/openstack_deploy/user_variables.yml
fi
# TODO: We need to eventually find a proper way to migrate these secret variables.
#       For now, we just copy existing secret variables defined previously on the
#       liberty install. This won't cause any problems since there aren't any new
#       secret variables in mitaka that are not defined in liberty.
if [[ -f "/etc/openstack_deploy/user_extras_secrets.yml" ]]; then
  mv /etc/openstack_deploy/user_extras_secrets.yml \
     /etc/openstack_deploy/user_rpco_secrets.yml
fi
if [[ -f "/etc/openstack_deploy/user_secrets.yml" ]]; then
  mv /etc/openstack_deploy/user_secrets.yml \
     /etc/openstack_deploy/user_osa_secrets.yml
fi
cp -a ${RPCD_DIR}/etc/openstack_deploy/*defaults* /etc/openstack_deploy

# TASK #1
# Update Ansible
if [[ -f "/root/.pip/pip.conf" ]]; then
  rm /root/.pip/pip.conf
fi
cd ${OA_DIR}
bash scripts/bootstrap-ansible.sh

# TASK #2
# Update the rpc-openstack galaxy modules
ansible-galaxy install --role-file=${BASE_DIR}/ansible-role-requirements.yml --force \
--roles-path=${RPCD_DIR}/playbooks/roles

# TASK #3
# Bug:   https://github.com/rcbops/u-suk-dev/issues/293
# Issue: We need to analyze support's maintenance plan to determine which
# pieces we can orchestrate with ansible. This should be added to a
# pre-upgrade task list.
cd ${RPCD_DIR}/playbooks
openstack-ansible rpc-pre-upgrades.yml

# TASK #4
# Bug: https://github.com/rcbops/u-suk-dev/issues/199
# Issue: To avoid any dependency issues that have occured in the past, the
#        repo_server containers are re-built. This was done as part of the
#        OSA upgrade script in liberty, but is not done in the OSA mitaka
#        upgrade script. Thus, we destroy the containers here.
cd ${OA_DIR}/playbooks
openstack-ansible lxc-containers-destroy.yml --limit repo_all
openstack-ansible setup-hosts.yml --limit repo_all

# TASK #5
# Bug:   https://github.com/rcbops/u-suk-dev/issues/374
# Issue: Neutron has no migration to correctly set the MTU on existing networks
#        created in liberty or below.  This work-around sets the MTU on these
#        networks before the upgrade starts so that instances booted on these
#        networks after the upgrade has finished will have their MTUs set
#        correctly.
# NOTE: In newton, MTUs will be calculated on the fly and this mtu field will
#       get dropped.
VLAN_FLAT="UPDATE networks SET mtu='1500' WHERE id IN (SELECT network_id FROM ml2_network_segments WHERE network_type IN ('vlan','flat'));"
VXLAN="UPDATE networks SET mtu='1450' WHERE id IN (SELECT network_id FROM ml2_network_segments WHERE network_type='vxlan');"

cd ${OA_DIR}/playbooks
ansible galera_all[0] -m shell -a "mysql --verbose -e \"${VLAN_FLAT}\" neutron"
ansible galera_all[0] -m shell -a "mysql --verbose -e \"${VXLAN}\" neutron"

# TASK #6
# Bug:   https://github.com/rcbops/u-suk-dev/issues/383
# Issue: The ceph-all.yml playbook will fail because of the hostname
#        changes introduced in Mitaka. This section recreates the mons
#        in a rolling fashion so quorum is maintained, and hostnames
#        are properly referenced in the ceph datasets(i.e monmap)
# NOTE:  Before running test-upgrade.sh on an AIO with ceph, variables
#        in the overrides file will need to be generated manually by
#        running migrate-yaml.py(similiar to TASK #0). The deployer
#        must ensure that osd_directory and raw_mutli_journal are not
#        both set to True in user_rpco_variables_overrides.yml. If this
#        isn't done, this TASK will fail.
#        In gating this is handled by gate-specific overrides set in
#        the jenkins-rpc repository.

# These are the instructions to give if there is a failure message on ceph-mon.yml
mons=$(ansible mons --list-hosts)
if [ $(echo ${mons} | wc -w) -gt 0 ]; then
  #Gather facts about all the monitors first, even with bad names
  #This shouldn't change a thing, it's a regular playbook run.
  openstack-ansible ${RPCD_DIR}/playbooks/gen-facts.yml
  for mon in ${mons}; do
    ansible $mon -m command -a "stop ceph-mon id=$mon"
    ansible $mon -m command -a "ceph mon remove $mon"
    openstack-ansible lxc-containers-destroy.yml --skip-tags=container-directories --limit $mon
    openstack-ansible lxc-containers-create.yml --limit $mon
    # Destroy facts for the current mon, this way it's gonna be properly generated
    rm -f /etc/openstack_deploy/ansible_facts/$mon
    openstack-ansible ${RPCD_DIR}/playbooks/ceph-mon.yml --limit $mon
  done
  #all the facts are good, they are all part of the cluster. just reconfigure them all
  openstack-ansible ${RPCD_DIR}/playbooks/ceph-all.yml
fi

# TASK #7
# https://github.com/rcbops/u-suk-dev/issues/392
# Upgrade openstack-ansible
pushd ${OA_DIR}
export I_REALLY_KNOW_WHAT_I_AM_DOING=true
echo "YES" | ${OA_DIR}/scripts/run-upgrade.sh
popd

# TASK #8
# Set upgrade variables for the RPCO playbooks
# The variables are put into a temporary user_variables file, then deleted
# at the end of this script.
touch ${UPGRADE_VARIABLES_FILE}
if grep -q 'logging_upgrade' ${UPGRADE_VARIABLES_FILE}; then
  sed -i "s/logging_upgrade:.*$/logging_upgrade: true/" ${UPGRADE_VARIABLES_FILE}
else
  echo "logging_upgrade: true" >> ${UPGRADE_VARIABLES_FILE}
fi

# TASK #9
# https://github.com/rcbops/u-suk-dev/issues/393
# Run deploy-rpc-playbooks.sh
# Ultimitely, this will run the RPCO playbooks.
cd ${BASE_DIR}
export DEPLOY_HAPROXY=${DEPLOY_HAPROXY:-"no"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"yes"}
bash scripts/deploy-rpc-playbooks.sh

# TASK #10
# Bug: https://github.com/rcbops/u-suk-dev/issues/366
# Description: Run post-upgrade tasks.
#              For a detailed description, please see the README in
#              the rpc_post_upgrade role directory.
cd ${RPCD_DIR}/playbooks
openstack-ansible rpc-post-upgrades.yml

rm ${UPGRADE_VARIABLES_FILE}
