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
set -eux
set -o pipefail

## Vars ----------------------------------------------------------------------

export SCRIPT_PATH="$(readlink -f $(dirname ${0}))"

## Functions -----------------------------------------------------------------
source "${SCRIPT_PATH}/functions.sh"

## Main ----------------------------------------------------------------------

# Generate the secrets required for the deployment.
if [[ ! -f "/etc/openstack_deploy/user_rpco_secrets.yml" ]]; then
  cp ${SCRIPT_PATH}/../etc/openstack_deploy/user_rpco_secrets.yml.example /etc/openstack_deploy/user_rpco_secrets.yml
fi

for file_name in user_secrets.yml user_rpco_secrets.yml; do
  if [[ -f "/etc/openstack_deploy/${file_name}" ]]; then
    python /opt/openstack-ansible/scripts/pw-token-gen.py --file "/etc/openstack_deploy/${file_name}"
  fi
done

if [ "${DEPLOY_AIO:-false}" != false ]; then
  cp "${SCRIPT_PATH}/user_aio_variables.yml" /etc/openstack_deploy/user_aio_variables.yml
fi

# Begin the RPC installation by uploading images and creating flavors.
pushd "${SCRIPT_PATH}/../playbooks"
  # Create default VM images and flavors
  openstack-ansible site-openstack.yml

  # Deploy RPC operational modifications
  openstack-ansible site-ops.yml

  # Deploy logging tools
  openstack-ansible site-logging.yml
popd

if [ "${DEPLOY_MAAS}" != false ]; then
  pushd /opt/rpc-maas/playbooks
  # Deploy and configure RAX MaaS
    if [ "${DEPLOY_TELEGRAF}" != false ]; then
      # Set the rpc_maas vars.
      if [[ ! -f "/etc/openstack_deploy/user_rpco_maas_variables.yml" ]]; then
        envsubst < \
          ${SCRIPT_PATH}/../etc/openstack_deploy/user_rpco_maas_variables.yml.example > \
          /etc/openstack_deploy/user_rpco_maas_variables.yml
      fi

      # If influx port and IP are set enable the variable
      sed -i 's|^# influx_telegraf_targets|influx_telegraf_targets|g' /etc/openstack_deploy/user_rpco_maas_variables.yml
    fi
    # Run the rpc-maas setup process
    openstack-ansible site.yml
  popd
fi
