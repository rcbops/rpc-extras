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
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_OA=${DEPLOY_OA:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TELEGRAF=${DEPLOY_TELEGRAF:-"no"}
export DEPLOY_INFLUX=${DEPLOY_INFLUX:-"no"}
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_RALLY=${DEPLOY_RALLY:-"no"}
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
export DEPLOY_MAGNUM=${DEPLOY_MAGNUM:-"no"}
export DEPLOY_HARDENING=${DEPLOY_HARDENING:-"yes"}
export DEPLOY_RPC=${DEPLOY_RPC:-"yes"}
export DEPLOY_ARA=${DEPLOY_ARA:-"no"}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
export UNAUTHENTICATED_APT=${UNAUTHENTICATED_APT:-no}

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export OA_DIR="${BASE_DIR}/openstack-ansible"
export OA_OVERRIDES='/etc/openstack_deploy/user_osa_variables_overrides.yml'
export RPCD_DIR="${BASE_DIR}/rpcd"
export RPCD_OVERRIDES='/etc/openstack_deploy/user_rpco_variables_overrides.yml'
export RPCM_VARIABLES='/etc/openstack_deploy/user_rpcm_variables.yml'
export RPCD_SECRETS='/etc/openstack_deploy/user_rpco_secrets.yml'

export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-''}
export FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}

export HOST_SOURCES_REWRITE=${HOST_SOURCES_REWRITE:-"yes"}
export HOST_UBUNTU_REPO=${HOST_UBUNTU_REPO:-"http://mirror.rackspace.com/ubuntu"}
export HOST_RCBOPS_REPO=${HOST_RCBOPS_REPO:-"http://rpc-repo.rackspace.com"}

# Derive the rpc_release version from the group vars
export RPC_RELEASE="$(/opt/rpc-openstack/scripts/artifacts-building/derive-artifact-version.sh)"

# Read the OS information
source /etc/os-release
source /etc/lsb-release

## Functions -----------------------------------------------------------------

function run_ansible {
  openstack-ansible ${ANSIBLE_PARAMETERS} --forks ${FORKS} $@
}

function check_submodule_status {
  # Confirm OA_DIR is properly checked out
  submodulestatus=$(git submodule status ${OA_DIR})
  case "${submodulestatus:0:1}" in
    "-")
      echo "ERROR: rpc-openstack submodule is not properly checked out"
      exit 1
      ;;
    "+")
      echo "WARNING: rpc-openstack submodule does not match the expected SHA"
      ;;
    "U")
      echo "ERROR: rpc-openstack submodule has merge conflicts"
      exit 1
      ;;
  esac
}

function apt_artifacts_available {

  CHECK_URL="${HOST_RCBOPS_REPO}/apt-mirror/integrated/dists/${RPC_RELEASE}-${DISTRIB_CODENAME}"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function git_artifacts_available {

  CHECK_URL="${HOST_RCBOPS_REPO}/git-archives/${RPC_RELEASE}/requirements.checksum"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function python_artifacts_available {

  ARCH=$(uname -p)
  CHECK_URL="${HOST_RCBOPS_REPO}/os-releases/${RPC_RELEASE}/${ID}-${VERSION_ID}-${ARCH}/MANIFEST.in"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function container_artifacts_available {

  CHECK_URL="${HOST_RCBOPS_REPO}/meta/1.0/index-system"

  if curl --silent --fail ${CHECK_URL} | grep "^${ID};${DISTRIB_CODENAME};.*${RPC_RELEASE};" > /dev/null; then
    return 0
  else
    return 1
  fi

}

function configure_apt_sources {

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
