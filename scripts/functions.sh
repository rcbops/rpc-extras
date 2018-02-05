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

# Read the OS information
for rc_file in openstack-release os-release lsb-release redhat-release; do
  if [[ -f "/etc/${rc_file}" ]]; then
    source "/etc/${rc_file}"
  fi
done

# Other
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export HOST_RCBOPS_DOMAIN="rpc-repo.rackspace.com"
export HOST_RCBOPS_REPO=${HOST_RCBOPS_REPO:-"http://${HOST_RCBOPS_DOMAIN}"}
export RPC_APT_ARTIFACT_ENABLED=${RPC_APT_ARTIFACT_ENABLED:-"no"}
export RPC_APT_ARTIFACT_MODE=${RPC_APT_ARTIFACT_MODE:-"strict"}
export RPC_RELEASE="$(${BASE_DIR}/scripts/get-rpc_release.py -f ${BASE_DIR}/playbooks/vars/rpc-release.yml)"
export RPC_OS="${ID}-${VERSION_ID}-x86_64"
export RPC_ANSIBLE_VERSION="2.3.2.0"
export RPC_ANSIBLE="${HOST_RCBOPS_REPO}/pools/${RPC_OS}/ansible/ansible-${RPC_ANSIBLE_VERSION}-py2-none-any.whl"
export RPC_LINKS="${HOST_RCBOPS_REPO}/links"

# Validate that RPC_RELEASE is set and has a value
# before continuing. If it is not, then something has
# gone wrong.
if [ "${RPC_RELEASE}" == "" ]; then
  echo "Something has gone wrong: RPC_RELEASE has no value."
  exit 1
fi
