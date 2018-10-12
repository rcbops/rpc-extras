#!/usr/bin/env bash
# Copyright 2014-2017, Rackspace US, Inc.
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
set -eux
set -o pipefail

## Vars ----------------------------------------------------------------------

export SCRIPT_PATH="$(readlink -f $(dirname ${0}))"

## Functions -----------------------------------------------------------------
function exit_notice {
  cat "${SCRIPT_PATH}/../README.md"
}

function basic_install {
  # Run the RPC-O installation process
  bash -c "${SCRIPT_PATH}/install.sh"
}

## Main ----------------------------------------------------------------------

# Setup OpenStack
if [ "${DEPLOY_AIO:-false}" != false ]; then
  ## Run the basic installation script
  basic_install

  # Install OpenStack-Ansible
  openstack-ansible "${SCRIPT_PATH}/../playbooks/openstack-ansible-install.yml"

  # RO-4206
  # Use fork of Ansible which exposes the apt errors so that we
  # can diagnose the cause of the apt fetch failures.
  export ANSIBLE_PACKAGE="git+https://github.com/rcbops/ansible@v2.3-OSA_SHA-with_apt_errors"

  # RO-4211
  # Implement debug output for apt so that we can see more information
  # about whether the 'Acquire-by-hash' feature is being used, and what
  # might be causing it to fall back to the old style.
  # This config file should be copied into containers by the lxc_hosts
  # role.
  echo 'Debug::Acquire::http "true";' > /etc/apt/apt.conf.d/99debug

  # NOTE(odyssey4me):
  # The test execution nodes do not have these packages installed, so
  # we need to do that until an upstream patch is merged and used by
  # RPC-O which does not require it to be installed, or installs the
  # required packages, before running gate-check-commit.
  apt-get install -y iptables util-linux

  ## Create the AIO
  pushd /opt/openstack-ansible
    bash -c "ANSIBLE_ROLE_FILE='/tmp/does-not-exist' scripts/gate-check-commit.sh"
  popd

  # Deploy RPC-OpenStack.
  bash -c "DEPLOY_AIO=true ${SCRIPT_PATH}/deploy-rpco.sh"
else
  basic_install
  exit_notice
fi
