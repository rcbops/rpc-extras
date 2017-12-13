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
# Set the DEPLOY_ variables to true to enable these services
export DEPLOY_AIO=${DEPLOY_AIO:-false}
export DEPLOY_MAAS=${DEPLOY_MAAS:-false}
export DEPLOY_TELEGRAF=${DEPLOY_TELEGRAF:-false}
export DEPLOY_INFLUX=${DEPLOY_INFLUX:-false}

# To send data to the influxdb server, we need to deploy and configure
#  telegraf. By default, telegraf will use log_hosts (rsyslog hosts) to
#  define its influxdb servers. These playbooks need maas-get to have run
#  previously.
# Set the following variables when when deploying maas with influx to log
#  to our upstream influx server.
export INFLUX_IP="${INFLUX_IP:-127.0.0.1}"
export INFLUX_PORT="${INFLUX_PORT:-8086}"

# Set the build tag to create a unique ID within influxdb
export BUILD_TAG="${BUILD_TAG:-testing}"

# RPC-OpenStack product release, this variable is used in the config playbooks.
export RPC_PRODUCT_RELEASE="${RPC_PRODUCT_RELEASE:-pike}"

# OSA release
if [ -z ${OSA_RELEASE+x} ]; then
  if [[ "${RPC_PRODUCT_RELEASE}" != "master" ]]; then
    export OSA_RELEASE="stable/${RPC_PRODUCT_RELEASE}"
  else
    export OSA_RELEASE="master"
  fi
fi

# Other
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export HOST_RCBOPS_REPO=${HOST_RCBOPS_REPO:-"http://rpc-repo.rackspace.com"}
export RPC_RELEASE="$(${BASE_DIR}/scripts/get-rpc_release.py)"

# Read the OS information
for rc_file in openstack-release os-release lsb-release redhat-release; do
  if [[ -f "/etc/${rc_file}" ]]; then
    source "/etc/${rc_file}"
  fi
done
