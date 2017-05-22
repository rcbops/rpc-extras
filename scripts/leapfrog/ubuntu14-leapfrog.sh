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

#export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
#export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
#export DEPLOY_OA=${DEPLOY_OA:-"yes"}
#export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
#export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
#export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
#export DEPLOY_RALLY=${DEPLOY_RALLY:-"no"}
#export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
#export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
#export DEPLOY_MAGNUM=${DEPLOY_MAGNUM:-"no"}
#export DEPLOY_HARDENING=${DEPLOY_HARDENING:-"yes"}
#export DEPLOY_RPC=${DEPLOY_RPC:-"yes"}
#export DEPLOY_ARA=${DEPLOY_ARA:-"no"}
#export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
#export UNAUTHENTICATED_APT=${UNAUTHENTICATED_APT:-no}
#export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
#export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-''}
#export FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}
#export OA_DIR="${BASE_DIR}/openstack-ansible"
#export RPCD_DIR="${BASE_DIR}/rpcd"

## Standard Vars --------------------------------------------------------------
# BASE_DIR is where KILO is
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export OA_OVERRIDES='/etc/openstack_deploy/user_osa_variables_overrides.yml'
export RPCD_OVERRIDES='/etc/openstack_deploy/user_rpco_variables_overrides.yml'
export RPCD_SECRETS='/etc/openstack_deploy/user_rpco_secrets.yml'

## Leapfrog Vars ----------------------------------------------------------------------
# Location of the leapfrog tooling (where we'll do our checkouts and move the
# code at the end)
export NEWTON_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../ && pwd)"
export LEAPFROG_DIR=${LEAPFROG_DIR:-"/opt/rpc-leapfrog"}
export OA_OPS_REPO=${OA_OPS_REPO:-'https://github.com/openstack/openstack-ansible-ops.git'}
export OA_OPS_REPO_BRANCH=${OA_OPS_REPO_BRANCH:-'master'}
export RPCO_DEFAULT_FOLDER="/opt/rpc-openstack"
# Instead of storing the debug's log of run in /tmp, we store it in an
# folder that will get archived for gating logs
export DEBUG_PATH="/var/log/osa-leapfrog-debug.log"
export UPGRADE_LEAP_MARKER_FOLDER="/etc/openstack_deploy/upgrade-leap"

### Gating vars
# In gates, force the skip of the input validation.
# export VALIDATE_UPGRADE_INPUT=False

# In gates, ensure the following variables are set:
# neutron_legacy_ha_tool_enabled: yes >> /etc/openstack_deploy/user_variables.yml
# lxc_container_backing_store: dir >> /etc/openstack_deploy/user_variables.yml

### Functions -----------------------------------------------------------------

function log {
    echo "Task: $1 status: $2" >> ${DEBUG_PATH}
    if [[ "$2" == "ok" ]]; then
      touch /etc/openstack-deploy/upgrade-leap/${1}.complete
    fi
}

### Main ----------------------------------------------------------------------

# Setup the base work folders
if [[ ! -d ${LEAPFROG_DIR} ]]; then
  mkdir -p ${LEAPFROG_DIR}
fi

if [[ ! -d "${UPGRADE_LEAP_MARKER_FOLDER}" ]]; then
    mkdir -p "${UPGRADE_LEAP_MARKER_FOLDER}"
fi

# Let's go
pushd ${LEAPFROG_DIR}


  # Get the OSA LEAPFROG
  if [[ ! -d "osa-leapfrog" ]]; then
      git clone ${OA_OPS_REPO} -b ${OA_OPS_REPO_BRANCH} osa-leapfrog
      log "clone" "ok"
  fi

  if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/osa-leap.complete" ]]; then
    pushd osa-leapfrog/leap-upgrades/
      ./run-stages.sh
    popd
    log "osa-leap" "ok"
  else
    log "osa-leap" "skipped"
  fi

  # Now that everything ran, you should have an OSA newton.
  # Cleanup the leapfrog remnants
  if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/osa-leap-cleanup.complete" ]]; then
    mv /opt/leap42 ./
    mv /opt/openstack-ansible* ./
    touch /etc/openstack_deploy/upgrade-leap/osa-leap-cleanup.complete
    log "osa-leap-cleanup" "ok"
  else
    log "osa-leap-cleanup" "skipped"
  fi

  # Re-deploy RPC.

  # Prepare rpc folder
  if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/rpc-prep.complete" ]]; then
    # If newton was cloned into a different folder than our
    # standard location (leapfrog folder?), we should make sure we
    # deploy the checked in version. If any remnabt RPC folder exist,
    # keep it under the LEAPFROG_DIR.
    if [[ ${NEWTON_BASE_DIR} != ${RPCO_DEFAULT_FOLDER} ]]; then
      # Cleanup existing RPC, replace with new RPC
      if [[ -d ${RPCO_DEFAULT_FOLDER} ]]; then
        mv ${RPCO_DEFAULT_FOLDER} ${LEAPFROG_DIR}/rpc-openstack.pre-newton
        cp -r ${NEWTON_BASE_DIR} ${RPCO_DEFAULT_FOLDER}
      fi
    fi
    log "rpc-prep" "ok"
  else
    log "rpc-prep" "skipped"
  fi

  if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/variable-migration.complete" ]]; then
    # Following docs: https://pages.github.rackspace.com/rpc-internal/docs-rpc/rpc-upgrade-internal/rpc-upgrade-v12-v13-perform.html#migrate-variables
    mkdir variables-backup
    pushd variables-backup
      cp /etc/openstack_deploy/user_extras_variables.yml ./user_extras_variables.yml.bak
        pushd ${RPCO_DEFAULT_FOLDER}/scripts
          ./migrate-yaml.py \
            --defaults ${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/user_rpco_variables_defaults.yml \
            --overrides /etc/openstack_deploy/user_extras_variables.yml \
            --output-file /etc/openstack_deploy/user_rpco_variables_overrides.yml \
            --for-testing-take-new-vars-only
        popd
      rm -f /etc/openstack_deploy/user_extras_variables.yml

      cp /etc/openstack_deploy/user_variables.yml ./user_variables.yml.bak
        pushd ${RPCO_DEFAULT_FOLDER}/scripts
          ./migrate-yaml.py \
            --defaults ${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/user_osa_variables_defaults.yml \
            --overrides /etc/openstack_deploy/user_variables.yml \
            --output-file /etc/openstack_deploy/user_osa_variables_overrides.yml
            --for-testing-take-new-vars-only
        popd
      rm -f /etc/openstack_deploy/user_variables.yml
      
      cp /etc/openstack_deploy/*_secrets.yml ./
      pushd ${RPCO_DEFAULT_FOLDER}/scripts
        python2.7 ./update-yaml.py \
          --defaults ${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/user_rpco_secrets.yml \
          --overrides /etc/openstack_deploy/user_extras_secrets.yml \
          --output-file /etc/openstack_deploy/user_rpco_secrets.yml \
          --for-testing-take-new-vars-only
      popd
      rm -f /etc/openstack_deploy/user_extras_secrets.yml

      python2.7 ${RPCO_DEFAULT_FOLDER}/openstack-ansible/scripts/pw-token-gen.py \
        --file /etc/openstack_deploy/user_rpco_secrets.yml
      mv /etc/openstack_deploy/user_secrets.yml /etc/openstack_deploy/user_osa_secrets.yml
      rm -f /etc/openstack_deploy/user_extras_secrets.yml /etc/openstack_deploy/user_secrets.yml
      cp ${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/*defaults* /etc/openstack_deploy
    popd
    log "variable-migration" "ok"
  else
    log "variable-migration" "skipped"
  fi

  if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/deploy-rpc.complete" ]]; then
    pushd ${RPCO_DEFAULT_FOLDER}
      scripts/deploy.sh
    popd
    log "deploy-rpc" "ok"
  else
    log "deploy-rpc" "skipped"
  fi
popd
