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

# Vars used for bootstrapping artifact configurations
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export HOST_SOURCES_REWRITE=${HOST_SOURCES_REWRITE:-"yes"}
export HOST_UBUNTU_REPO=${HOST_UBUNTU_REPO:-"http://mirror.rackspace.com/ubuntu"}
export HOST_RCBOPS_REPO=${HOST_RCBOPS_REPO:-"http://rpc-repo.rackspace.com"}

# Read the OS information
for rc_file in openstack-release os-release lsb-release redhat-release; do
  if [[ -f "/etc/${rc_file}" ]]; then
    source "/etc/${rc_file}"
  fi
done

## Functions -----------------------------------------------------------------

# Sourced from https://stackoverflow.com/a/21189044
# Modified to remove the unnecessary prefix option,
# and to please bashate.
function parse_yaml {
   s='[[:space:]]*'
   w='[a-zA-Z0-9_]*'
   fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s=\"%s\"\n", vn, $2, $3);
      }
   }'
}

function apt_artifacts_available {

  CHECK_URL="${HOST_RCBOPS_REPO}/apt-mirror/integrated/dists/${RPC_RELEASE}-${DISTRIB_CODENAME}"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function configure_apt_sources {

  # Backup the original sources file
  if [[ ! -f "/etc/apt/sources.list.original" ]]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.original
  fi

  # Replace the existing apt sources with the artifacted sources.

  sed -i '/^deb-src /d' /etc/apt/sources.list
  sed -i '/-backports /d' /etc/apt/sources.list
  sed -i '/-security /d' /etc/apt/sources.list
  sed -i '/-updates /d' /etc/apt/sources.list

  # Add the RPC-O apt repo source
  echo "deb ${HOST_RCBOPS_REPO}/apt-mirror/integrated/ ${RPC_RELEASE}-${DISTRIB_CODENAME} main" \
    > /etc/apt/sources.list.d/rpco.list

  # Install the RPC-O apt repo key
  curl --silent --fail ${HOST_RCBOPS_REPO}/apt-mirror/rcbops-release-signing-key.asc | apt-key add -

}

## Main ----------------------------------------------------------------------

# To avoid needing to install python on the host, we use a bash
# function here to extract the rpc_release value for the series
# being installed. This is needed to be able to figure out whether
# apt artifacts are available for the release and to set them up
# prior to installing any packages.
export RPC_RELEASE=$(parse_yaml ${BASE_DIR}/playbooks/vars/rpc-release.yml | grep "rpc_product_releases_${RPC_PRODUCT_RELEASE}_rpc_release" | cut -d= -f 2 | tr -d '"')
