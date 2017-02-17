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

export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_OA=${DEPLOY_OA:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_RALLY=${DEPLOY_RALLY:-"no"}
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
export DEPLOY_MAGNUM=${DEPLOY_MAGNUM:-"no"}
export DEPLOY_HARDENING=${DEPLOY_HARDENING:-"yes"}
export DEPLOY_RPC=${DEPLOY_RPC:-"yes"}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
export UNAUTHENTICATED_APT=${UNAUTHENTICATED_APT:-no}

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export OA_DIR="${BASE_DIR}/openstack-ansible"
export OA_OVERRIDES='/etc/openstack_deploy/user_osa_variables_overrides.yml'
export RPCD_DIR="${BASE_DIR}/rpcd"
export RPCD_OVERRIDES='/etc/openstack_deploy/user_rpco_variables_overrides.yml'
export RPCD_SECRETS='/etc/openstack_deploy/user_rpco_secrets.yml'

export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-''}
export FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}

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
