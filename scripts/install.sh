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

## Run first ------------------------------------------------------------------
# NOTE(cloudnull): Install the minimum packages required before anything can be
#                  executed. While these should have been included in the base
#                  kick, if they were not, they will need to be installed prior
#                  to doing anything else.
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
                                       python \
                                       python-yaml \
                                       python-virtualenv

## Vars ----------------------------------------------------------------------
export SCRIPT_PATH="$(readlink -f $(dirname ${0}))"

## Functions -----------------------------------------------------------------
source "${SCRIPT_PATH}/functions.sh"

function install_ansible_source {
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
                                            gcc libssl-dev libffi-dev \
                                            python-apt python3-apt \
                                            python-dev python3-dev \
                                            python-minimal python-virtualenv

  /opt/rpc-ansible/bin/pip install "ansible==${RPC_ANSIBLE_VERSION}"
}

## Main ----------------------------------------------------------------------
# If /opt/openstack-ansible exists, delete it if it is not a git checkout
if [[ -d "/opt/openstack-ansible" ]] && [[ ! -d "/opt/openstack-ansible/.git" ]]; then
  mv /opt/openstack-ansible /opt/openstack-ansible.original
fi

# NOTE(cloudnull): Create a virtualenv for RPC-Ansible which is used for
#                  initial bootstrap purposes. While playbooks can be run using
#                  this ansible release in the general sense, the OSA ansible
#                  version will superseed this globally.
virtualenv /opt/rpc-ansible

# Install a Ansible for RPC-OpenStack.
install_ansible_source

# NOTE(cloudnull): This will only created the minimal wrapper if
#                  OpenStack-Ansible has not been installed. The
#                  wrapper is single use until OSA is prep'd.
#                  Because OSA will overrwite this file the
#                  command is setting the exit code when a Run
#                  succeeds. Variable exports are here so that
#                  the dependent roles RPC-OpenStack is using,
#                  pip_install, has access to all of the things
#                  it will need.
if [[ ! -f "/usr/local/bin/openstack-ansible" ]]; then
  cp "${SCRIPT_PATH}/openstack-ansible-wrapper.sh" /usr/local/bin/openstack-ansible
  chmod +x /usr/local/bin/openstack-ansible
fi

# Setup the basic release
pushd "${SCRIPT_PATH}/../playbooks"
  openstack-ansible site-release.yml
popd
