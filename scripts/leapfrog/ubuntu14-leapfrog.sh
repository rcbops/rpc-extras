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
#
# (c) 2017, Jean-Philippe Evrard <jean-philippe.evrard@rackspace.co.uk>

## Shell Opts ----------------------------------------------------------------
set -e -u
set -o pipefail

## Base dir ------------------------------------------------------------------
# Location of the leapfrog tooling (where we'll do our checkouts and move the
# code at the end)
export NEWTON_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../ && pwd)"

## Loading variables ---------------------------------------------------------

if [ -z ${BUILD_URL+x} ]; then
    export IS_GATING="FALSE"
else
    echo "YOU ARE RUNNING THE GATES"
    export IS_GATING="TRUE"
fi
source ${NEWTON_BASE_DIR}/scripts/functions.sh

# BASE_DIR and variable files should be loaded.
# By default BASE_DIR could be where KILO is, if newton is checked out into
# a different folder. We need to take this case into consideration.

## Leapfrog Vars ----------------------------------------------------------------------
export RPCO_DEFAULT_FOLDER="/opt/rpc-openstack"
# Temp location for the code and config files backups.
export LEAPFROG_DIR=${LEAPFROG_DIR:-"/opt/rpc-leapfrog"}
# OSA leapfrog tooling location
export OA_OPS_REPO=${OA_OPS_REPO:-'https://github.com/openstack/openstack-ansible-ops.git'}
# Please bump the following when a patch for leapfrog is merged into osa-ops
# If you are developping, just clone your ops repo into (by default)
# /opc/rpc-leapfrog/openstack-ansible-ops
export OA_OPS_REPO_BRANCH=${OA_OPS_REPO_BRANCH:-'c1a4219a5ac9f634afae695be8d6dea0e1e31059'}
# Instead of storing the debug's log of run in /tmp, we store it in an
# folder that will get archived for gating logs
export DEBUG_PATH="/var/log/osa-leapfrog-debug.log"
export UPGRADE_LEAP_MARKER_FOLDER="/etc/openstack_deploy/upgrade-leap"
export PRE_LEAP_STEPS="${NEWTON_BASE_DIR}/scripts/leapfrog/pre_leap.sh"
export POST_LEAP_STEPS="${NEWTON_BASE_DIR}/scripts/leapfrog/post_leap.sh"
export RPCD_DEFAULTS='/etc/openstack_deploy/user_rpco_variables_defaults.yml'
export OA_DEFAULTS='/etc/openstack_deploy/user_osa_variables_defaults.yml'

### Functions -----------------------------------------------------------------
function set_gating_vars {
    if [[ -f /etc/openstack_deploy/user_variables.yml ]]; then
    cat << EOF >> /etc/openstack_deploy/user_variables.yml
neutron_legacy_ha_tool_enabled: "yes"
lxc_container_backing_store: "dir"
EOF
    fi
}

function log {
    echo "Task: $1 status: $2" >> ${DEBUG_PATH}
    if [[ "$2" == "ok" ]]; then
        touch /etc/openstack_deploy/upgrade-leap/${1}.complete
    fi
}

### Main ----------------------------------------------------------------------
if [[ "${IS_GATING}" == "TRUE" ]]; then
    set -x
    # force the skip of the input validation.
    export VALIDATE_UPGRADE_INPUT=False
    export AUTOMATIC_VAR_MIGRATE_FLAG="--for-testing-take-new-vars-only"
    set_gating_vars
fi

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
    if [[ ! -d "openstack-ansible-ops" ]]; then
        git clone ${OA_OPS_REPO}
        pushd openstack-ansible-ops
            git checkout ${OA_OPS_REPO_BRANCH}
        popd
        log "clone" "ok"
    fi

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
    # Now the following directory structure is in place
    # /opt
    #     /rpc-leapfrog
    #                  /openstack-ansible-ops    # contains osa ops full repo
    #                  /rpc-openstack.pre-newton # contains old
    #                                            # /opt/rpc-openstack
    #     /rpc-openstack # contains rpc-openstack newton tooling

    ############################################
    # We should be good to go for the leapfrog #
    ############################################

    # We probably want to migrate vars here, before the first leapfrog
    # and deploy of OSA newton.

    # We could also set here exports to override the OSA
    # ops tooling, for example to change the version of OSA
    # we are deploying to (be in sync with RPC 's OSA sha), in order
    # to avoid double leap

    # There is no way we can verify the integrity of the loaded steps,
    # Therefore we shouldn't include a marker in this script.
    # In other words, this should always run. The script itself can
    # use the same mechanism as what we are using here
    if [[ -f ${PRE_LEAP_STEPS} ]]; then
        source ${PRE_LEAP_STEPS}
    fi

    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/osa-leap.complete" ]]; then
        pushd openstack-ansible-ops/leap-upgrades/
            export REDEPLOY_EXTRA_SCRIPT=${RPCO_DEFAULT_FOLDER}/scripts/leapfrog/pre_redeploy.sh
            . ./run-stages.sh
        popd
        log "osa-leap" "ok"
    else
        log "osa-leap" "skipped"
    fi
    # Now the following directory structure is in place
    # /opt
    #     /rpc-leapfrog
    #                  /openstack-ansible-ops    # contains osa ops full repo
    #                  /rpc-openstack.pre-newton # contains old
    #                                            # /opt/rpc-openstack
    #     /rpc-openstack     # contains rpc-openstack newton tooling
    #     /leap42            # contains the remnants of the leap tooling
    #     /openstack-ansible # contains the version the OSA leaped into

    # Now that everything ran, you should have an OSA newton.
    # Cleanup the leapfrog remnants
    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/osa-leap-cleanup.complete" ]]; then
        mv /opt/leap42 ./
        mv /opt/openstack-ansible* ./
        log "osa-leap-cleanup" "ok"
    else
        log "osa-leap-cleanup" "skipped"
    fi
    # Now the following directory structure is in place
    # /opt
    #     /rpc-leapfrog
    #                  /openstack-ansible-ops    # contains osa ops
    #                                            # complete repo
    #                  /rpc-openstack.pre-newton # contains old
    #                                            # /opt/rpc-openstack
    #                  /leap42                   # contains the remnants of
    #                                            # the leap tooling
    #                  /openstack-ansible        # contains the version
    #                                            # the OSA leaped into
    #     /rpc-openstack     # contains rpc-openstack newton tooling

    #####################
    # OSA LEAPFROG done #
    # Re-deploy RPC     #
    #####################

    # There is no way we can verify the integrity of the loaded steps,
    # Therefore we shouldn't include a marker in this script.
    if [[ -f ${POST_LEAP_STEPS} ]]; then
        source ${POST_LEAP_STEPS}
    fi
    # Arbitrary code execution is evil, we should do better when we
    # know what we need.
popd
