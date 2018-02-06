#!/usr/bin/env bash
#
# Copyright 2014-2017, Rackspace US, Inc.
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

## Functions -----------------------------------------------------------------

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

## Main ----------------------------------------------------------------------

# Check the openstack-ansible submodule status
check_submodule_status

# Get minimum disk size
DATA_DISK_MIN_SIZE="$((1024**3 * $(awk '/bootstrap_host_data_disk_min_size/{print $2}' ${OA_DIR}/tests/roles/bootstrap-host/defaults/main.yml) ))"
# Determine the largest secondary disk device available for repartitioning which meets the minimum size requirements
DATA_DISK_DEVICE=$(lsblk -brndo NAME,TYPE,RO,SIZE | \
                   awk '/d[b-z]+ disk 0/{ if ($4>m && $4>='$DATA_DISK_MIN_SIZE'){m=$4; d=$1}}; END{print d}')
# Only set the secondary disk device option if there is one
if [ -n "${DATA_DISK_DEVICE}" ]; then
  export BOOTSTRAP_OPTS="${BOOTSTRAP_OPTS} bootstrap_host_data_disk_device=${DATA_DISK_DEVICE}"
fi

# This toggles whether the AIO bootstrap will
# clean out the apt sources or not. When there
# are artifacts available, it should, because
# the rpco sources file will be added. When
# artifacts are not available then the updates
# repo is needed.
# The RPCO_APT_ARTIFACTS_AVAILABLE env var is
# used to provide the right information to the
# bootstrap-aio.yml playbook which rewrites the
# /etc/apt/sources.list file.
if apt_artifacts_available; then
  export RPCO_APT_ARTIFACTS_AVAILABLE="yes"
else
  export RPCO_APT_ARTIFACTS_AVAILABLE="no"
  rm -f ${BASE_DIR}/group_vars/all/apt.yml
  sed -i '/^# Apt artifact repo configuration$/,$d' ${RPCD_DIR}/etc/openstack_deploy/user_rpco_variables_defaults.yml
fi

# Run AIO bootstrap playbook
# Setting GROUP_VARS and HOST_VARS to their original
# values here so that the OSA bootstrap playbooks
# can run with the correct variables.
export GROUP_VARS_PATH="/etc/openstack_deploy/group_vars/"
export HOST_VARS_PATH="/etc/openstack_deploy/host_vars/"
openstack-ansible -vvv ${BASE_DIR}/scripts/bootstrap-aio.yml \
                  -i "localhost," -c local \
                  -e "${BOOTSTRAP_OPTS}"
# Unset GROUP_VARS_PATH and HOST_VARS_PATH so that the
# defaults are taken in openstack-ansible.rc
unset GROUP_VARS_PATH
unset HOST_VARS_PATH
