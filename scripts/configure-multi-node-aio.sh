#!/usr/bin/env bash
#
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

## Functions -----------------------------------------------------------------

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

## Main ----------------------------------------------------------------------

# Check the openstack-ansible submodule status
check_submodule_status

# Run multi-node AIO config setup playbook
export TARGET=${TARGET:-"mnaio"}
openstack-ansible -vvv ${BASE_DIR}/scripts/configure-multi-node-aio.yml \
                  -i "localhost," -c local

if ! apt_artifacts_available; then
  # Remove the AIO configuration relating to the use
  # of apt artifacts. This needs to be done because
  # the apt artifacts do not exist yet.
  sed -i '/^rpco_mirror_base_url/,$d' /etc/openstack_deploy/user_osa_variables_defaults.yml
fi

# If there are no container artifacts for this release, then remove the container artifact configuration
if ! container_artifacts_available; then
  # Remove the AIO configuration relating to the use
  # of container artifacts. This needs to be done
  # because the container artifacts do not exist yet.
  ./scripts/artifacts-building/remove-container-aio-config.sh
fi
