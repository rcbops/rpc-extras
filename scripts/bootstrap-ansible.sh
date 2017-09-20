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
export ANSIBLE_ROLE_FETCH_MODE=${ANSIBLE_ROLE_FETCH_MODE:-git-clone}

## Main ----------------------------------------------------------------------

# If the installation is an upgrade the $OS_DIR path will alredy exist from a
#  previous submodule checkout. In the event that it does exist, this will move
#  the directory to the proper location.
if git config --file "${BASE_DIR}/.gitmodules" --name-only --get-regexp path | grep -q "openstack-ansible" && [[ -d "${OA_DIR}" ]]; then
  mv "${OA_DIR}" /opt/openstack-ansible
elif [[ ! -L "${BASE_DIR}/openstack-ansible" ]] && [[ -d "${BASE_DIR}/openstack-ansible/.git" ]]; then
  mv "${OA_DIR}" /opt/openstack-ansible
elif [[ ! -d "/opt/openstack-ansible" ]]; then
  git clone https://git.openstack.org/openstack/openstack-ansible /opt/openstack-ansible
fi

# Check that the OA_DIR is a symlink.
# NOTE(cloudnull): this is only needed to keep the legacy interface intact. Once
#                  we're able to get away from the submodule pattern entirely
#                  and clean up the code that expects this nested OSA path we
#                  can remove the link and just use the already documented,
#                  upstream, directory pathing.
if [[ ! -L "${BASE_DIR}/openstack-ansible" ]]; then
  if [[ -d "${BASE_DIR}/openstack-ansible" ]]; then
    rm -rf "${BASE_DIR}/openstack-ansible"
  fi
  ln -sf /opt/openstack-ansible "${BASE_DIR}/openstack-ansible"
fi

# Run git checkout on OSA
pushd "/opt/openstack-ansible"
  git checkout "${OSA_RELEASE}"
popd


# The deployment host must only have the base Ubuntu repository configured.
# All updates (security and otherwise) must come from the RPC-O apt artifacting.
#
# This is being done via bash because Ansible is not bootstrapped yet, and the
# apt artifacts used for bootstrapping Ansible must also come from the RPC-O
# artifact repo.
#
# This has the ability to be disabled for the purpose of reusing the
# bootstrap-ansible script for putting together the apt artifacts.
if [[ "${HOST_SOURCES_REWRITE}" == 'yes' ]] && apt_artifacts_available; then
  configure_apt_sources
  downgrade_installed_packages
fi

# begin the bootstrap process
pushd ${OA_DIR}

  ./scripts/bootstrap-ansible.sh

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

  # Now use GROUP_VARS of OSA and RPC
  sed -i "s|GROUP_VARS_PATH=.*|GROUP_VARS_PATH=\"\${GROUP_VARS_PATH:-${OA_DIR}/playbooks/inventory/group_vars/:${BASE_DIR}/group_vars/:/etc/openstack_deploy/group_vars/}\"|" /usr/local/bin/openstack-ansible.rc
  sed -i "s|HOST_VARS_PATH=.*|HOST_VARS_PATH=\"\${HOST_VARS_PATH:-${OA_DIR}/playbooks/inventory/host_vars/:${BASE_DIR}/host_vars/:/etc/openstack_deploy/host_vars/}\"|" /usr/local/bin/openstack-ansible.rc

popd
