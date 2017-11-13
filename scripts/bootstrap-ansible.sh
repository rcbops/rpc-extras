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

# If /opt/openstack-ansible exists, delete it if it is not a git clone
if [[ -d "/opt/openstack-ansible" ]] && [[ ! -d "/opt/openstack-ansible/.git" ]]; then
  rm -rf /opt/openstack-ansible
fi

# Git clone the openstack-ansible repository
if [[ ! -d "/opt/openstack-ansible" ]]; then
  git clone https://git.openstack.org/openstack/openstack-ansible /opt/openstack-ansible
fi

pushd "/opt/openstack-ansible"
  # Check if the current SHA does not match the desired SHA
  if [[ "$(git rev-parse HEAD)" != "${OSA_RELEASE}" ]]; then

    # If the SHA we want does not exist in the git repo, update the repo
    if ! git cat-file -e ${OSA_RELEASE} 2> /dev/null; then
      git fetch --all
    fi

    # Now checkout the correct SHA
    git checkout "${OSA_RELEASE}"
  fi
popd

# Check that the OA_DIR is a symlink.
# NOTE(cloudnull): this is only needed to keep the legacy interface intact. Once
#                  we're able to get away from the submodule pattern entirely
#                  and clean up the code that expects this nested OSA path we
#                  can remove the link and just use the already documented,
#                  upstream, directory pathing.
if [[ ! -L "${OA_DIR}" ]]; then
  ln -sf /opt/openstack-ansible "${OA_DIR}"
fi

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

  # NOTE(cloudnull): Sync {group,host}_vars from rpc-o into the proper OSA
  #                  directory which supports the default override interface.
  #                  to ensure our group and host vars are always in sync the
  #                  rsync command is used with the --delete flag and the vars
  #                  are set to read only. If a deployer wishes to override our
  #                  defaults they can do so using the user_.* files.
  for dir_name in group_vars host_vars; do
    if [[ -d "${BASE_DIR}/${dir_name}" ]];then
      rsync -av --exclude '*.bak' --delete "${BASE_DIR}/${dir_name}" /etc/openstack_deploy/
      if [[ -d "/etc/openstack_deploy/${dir_name}" ]]; then
        chmod ugo+rX "/etc/openstack_deploy/${dir_name}"
      fi
    fi
  done

popd
