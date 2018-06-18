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
                                       python-virtualenv \
                                       python3-virtualenv

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
# NOTE(cloudnull): Create a virtualenv for RPC-Ansible which is used for
#                  initial bootstrap purposes. While playbooks can be run using
#                  this ansible release in the general sense, the OSA ansible
#                  version will superseed this globally.
virtualenv /opt/rpc-ansible

# Install a Ansible for RPC-OpenStack.
install_ansible_source

# Setup the basic release
pushd "${SCRIPT_PATH}/../playbooks"
  /opt/rpc-ansible/bin/ansible-playbook -i 'localhost,' site-release.yml
popd
