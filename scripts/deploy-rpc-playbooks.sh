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
set -o pipefail

## Functions -----------------------------------------------------------------

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

## Main ----------------------------------------------------------------------

# begin the RPC installation
cd ${RPCD_DIR}/playbooks/

# configure everything for RPC support access
run_ansible rpc-support.yml

# deploy and configure RAX MaaS
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
  run_ansible setup-maas.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
  run_ansible setup-logging.yml
fi

# verify RAX MaaS is running after all necessary
# playbooks have been run
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
  ansible hosts -m shell -a "rm /etc/rackspace-monitoring-agent.conf.d/*.yaml"
  ansible hosts -m service -a "name=rackspace-monitoring-agent state=restarted"
  run_ansible verify-maas.yml
fi
