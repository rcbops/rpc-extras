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
if [[ "${DEPLOY_SUPPORT_ROLE}" == "yes" ]]; then
    run_ansible rpc-support.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
    run_ansible setup-logging.yml
fi

if [[ ! -f "${RPCM_VARIABLES}" ]]; then
  cp "${RPCD_DIR}/etc/openstack_deploy/user_rpcm_variables.yml" "${RPCM_VARIABLES}"
fi

# Download the latest release of rpc-maas
# TODO(odyssey4me):
# Remove this once rpc-gating no longer tries
# to run rpc-maas as its own thing and instead
# just uses deploy.sh end-to-end. This line
# should not be necessary as setup-maas.yml
# below includes maas-get.yml
run_ansible maas-get.yml

# Deploy and configure RAX MaaS
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
    # Run the rpc-maas setup process
    run_ansible setup-maas.yml

    # verify RAX MaaS is running after all necessary
    # playbooks have been run
    run_ansible verify-maas.yml
fi

# To send data to the influxdb server, we need to deploy and
# configure telegraf.
# By default, telegraf will use log_hosts (rsyslog hosts)
# to define its influxdb servers.
# These playbooks need maas-get to have run previously.
if [[ "${DEPLOY_TELEGRAF}" == "yes" ]]; then
    # BUILD_TAG is used as reference for gating.
    if [[ -n "${BUILD_TAG}" ]]; then
        # user_rpco_variables_overrides are generated at every build, so
        # we are fine to just echo it.
        echo 'maas_job_reference: "${BUILD_TAG}"' >> /etc/openstack_deploy/user_rpco_variables_overrides.yml
        # Telegraph shipping is done to influx nodes belonging to
        # influx_telegraf_targets | union(influx_all)
        cat >> /etc/openstack_deploy/user_rpco_variables_overrides.yml << EOF
influx_telegraf_targets:
  - "http://$INFLUX_IP:$INFLUX_PORT"
EOF
    fi
    run_ansible /opt/rpc-maas/playbooks/maas-tigkstack-telegraf.yml
fi

# Deploy Influx
if [[ "${DEPLOY_INFLUX}" == "yes" ]]; then
    # We'll assume the deployer has configured his environment
    # to define the influx_all servers.
    run_ansible /opt/rpc-maas/playbooks/maas-tigkstack-influxdb.yml
fi
