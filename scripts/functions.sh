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

# OSA SHA
export OSA_RELEASE="${OSA_RELEASE:-b79e7f36abeb054e888b4f6ea75219b5fb3b03b9}"
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}

# Gating
export BUILD_TAG=${BUILD_TAG:-}
export INFLUX_IP=${INFLUX_IP:-}
export INFLUX_PORT=${INFLUX_PORT:-"8086"}

# Other
export HOST_RCBOPS_REPO=${HOST_RCBOPS_REPO:-"http://rpc-repo.rackspace.com"}
export RPC_RELEASE="$(awk '/rpc_release/ { print $2; }' ${BASE_DIR}/etc/openstack_deploy/group_vars/all/release.yml | sed s'/"//'g)"

# Read the OS information
for rc_file in openstack-release os-release lsb-release redhat-release; do
  if [[ -f "/etc/${rc_file}" ]]; then
    source "/etc/${rc_file}"
  fi
done
