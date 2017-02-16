#!/usr/bin/env bash
# Copyright 2017, Rackspace US, Inc.
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

## Main ----------------------------------------------------------------------

# Check the openstack-ansible submodule status
check_submodule_status

# begin the bootstrap process
pushd ${OA_DIR}
    openstack-ansible ${RPCD_DIR}/playbooks/stage-apt-artifacts.yml
    openstack-ansible ${RPCD_DIR}/playbooks/stage-container-artifacts.yml
    openstack-ansible ${RPCD_DIR}/playbooks/stage-python-artifacts.yml
popd
