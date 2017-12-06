#!/usr/bin/env bash
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
set -euv
set -o pipefail

## Vars ----------------------------------------------------------------------
export DEPLOY_AIO=${DEPLOY_AIO:-false}

# NOTE(cloudnull): See comment further down, but this should be removed later.
export MARKER="/tmp/gate-check-commit.complete"

export SCRIPT_PATH="$(readlink -f $(dirname ${0}))"

## Functions -----------------------------------------------------------------
function exit_notice {
  echo -e "\n**System prepared for Installation**
To configure the installation please refer to the upstream OpenStack-Ansible
documentation regarding basic [system setup]
(https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/configure.html).

Prior to running the playbooks ensure your system(s) are using the latest
artifacts. To ensure all hosts have the same artifacts run the RPC-OpenStack
playbook \`site-artifacts.yml\`.

Once the deploy configuration has been completed please refer to the
OpenStack-Ansible documentation regarding [running the playbooks]
(https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/run-playbooks.html).

Upon completion of the deployment run \`scripts/deploy-rpco.sh\` script to
apply the RPC-OpenStack value added services; you may also run the playbooks
\`playbooks/site-logging.yml\` to accomplish much of the same things.
"
}

function basic_install {
  # Run the RPC-O installation process
  bash -c "${SCRIPT_PATH}/install.sh"
}

## Main ----------------------------------------------------------------------

# Setup OpenStack
if [ "${DEPLOY_AIO}" != false ]; then
  # Run the AIO job.
  # NOTE(cloudnull): Drop a marker after building an AIO and check for it's
  #                  existance. This is here because our CIT gating system
  #                  calls this script a mess of times with different
  #                  environment variables instead of leveraging a stable
  #                  interface and controlling the systems code paths within
  #                  a set of well known and understanable test scripts.
  #                  Because unwinding this within the CIT gate is impossible
  #                  at this time and there's no stable interface to consume
  #                  we check for and drop a marker file once the basic AIO
  #                  has been created. If the marker is found we skip trying to
  #                  build everything again.
  # NOTE(cloudnull): Remove this when we have a sane test interface.
  if [[ ! -f "${MARKER}" ]]; then
    ## Run the basic installation script
    basic_install

    # Force the AIO to use artifacts
    # NOTE(cloudnull): This disables container/py artifacts for now. The
    #                  RPC-OpenStack container/py artifacts are failing
    #                  while the upstream container/py builds of similart
    #                  sizes, packages, and distros is not showing the same
    #                  issues. We need to spend some time debugging how the
    #                  sources are built and how we can better construct and
    #                  consume them.
    openstack-ansible -i 'localhost,' \
                      -e apt_target_group=localhost \
                      -e 'container_artifact_enabled=false' \
                      -e 'py_artifact_enabled=false' \
                      ${SCRIPT_PATH}/../playbooks/site-artifacts.yml

    ## Create the AIO
    pushd /opt/openstack-ansible
      bash -c "scripts/gate-check-commit.sh"
    popd

    ## Drop the AIO marker file.
    touch ${MARKER}
  else
    echo "An AIO has already been created, remove \"${MARKER}\" to run again."
    exit_notice
  fi

  # Deploy RPC-OpenStack.
  bash -c "${SCRIPT_PATH}/deploy-rpco.sh"
else
  basic_install
  exit_notice
fi
