#!/usr/bin/env bash
# Copyright 2014-2017 , Rackspace US, Inc.
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

set -e -u -x
set -o pipefail

## Functions -----------------------------------------------------------------

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

## Vars ----------------------------------------------------------------------

# Set the role fetch mode to any option [galaxy, git-clone]
export ANSIBLE_ROLE_FETCH_MODE=${ANSIBLE_ROLE_FETCH_MODE:-galaxy}

## Main ----------------------------------------------------------------------

# Check the openstack-ansible submodule status
check_submodule_status

# The deployment host must only have the base Ubuntu repository configured.
# All updates (security and otherwise) must come from the RPC-O apt artifacting.
#
# This is being done via bash because Ansible is not bootstrapped yet, and the
# apt artifacts used for bootstrapping Ansible must also come from the RPC-O
# artifact repo.
#
# This has the ability to be disabled for the purpose of reusing the
# bootstrap-ansible script for putting together the apt artifacts.
if [[ "${HOST_SOURCES_REWRITE}" == 'yes' ]]; then
  apt_sources_back_to_stock
  apt_sources_use_rpc_apt_artifacts
fi

# begin the bootstrap process
pushd ${OA_DIR}

  ./scripts/bootstrap-ansible.sh

  # This removes legacy roles which were downloaded into the
  # rpc-o folder structure, dirtying the git tree.
  ansible-galaxy remove --roles-path /opt/rpc-openstack/rpcd/playbooks/roles/ \
                        ceph-common ceph-mon ceph-osd \
                        ceph.ceph-common ceph.ceph-mon ceph.ceph-osd \
                        rcbops_openstack-ops

  if [[ "${ANSIBLE_ROLE_FETCH_MODE}" == 'galaxy' ]];then
    # Pull all required roles.
    ansible-galaxy install --role-file="${BASE_DIR}/ansible-role-requirements.yml" \
                           --force
  elif [[ "${ANSIBLE_ROLE_FETCH_MODE}" == 'git-clone' ]];then
    ansible-playbook ${OA_DIR}/tests/get-ansible-role-requirements.yml \
                     -i ${OA_DIR}/tests/test-inventory.ini \
                     -e role_file="${BASE_DIR}/ansible-role-requirements.yml"
  else
    echo "Please set the ANSIBLE_ROLE_FETCH_MODE to either of the following options ['galaxy', 'git-clone']"
    exit 99
  fi

  # RPC-O has roles in its own git tree, so we need to add it to the
  # path for Ansible to search.
  sed -i "s|/etc/ansible/roles:roles|/etc/ansible/roles:roles:${RPCD_DIR}/playbooks/roles|" /usr/local/bin/openstack-ansible.rc

popd
