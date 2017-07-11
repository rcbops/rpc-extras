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

## Vars ----------------------------------------------------------------------

# Gating
export BUILD_TAG=${BUILD_TAG:-}
export INFLUX_IP=${INFLUX_IP:-}
export INFLUX_PORT=${INFLUX_IP:-"8086"}

# Other
export DEPLOY_SUPPORT_ROLE=${DEPLOY_SUPPORT_ROLE:-"no"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TELEGRAF=${DEPLOY_TELEGRAF:-"no"}
export DEPLOY_INFLUX=${DEPLOY_INFLUX:-"no"}

export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-''}
export FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export RPCD_DIR="${BASE_DIR}/rpcd"


function run_ansible {
  openstack-ansible ${ANSIBLE_PARAMETERS} --forks ${FORKS} $@
}
