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

set -evu

echo "Building a Multi Node AIO (MNAIO)"
echo "+-------------------- MNAIO ENV VARS --------------------+"
env
echo "+-------------------- MNAIO ENV VARS --------------------+"

## Vars ----------------------------------------------------------------------

# These vars are set by the CI environment, but are given defaults
# here to cater for situations where someone is executing the test
# outside of the CI environment.
export RE_JOB_NAME="${RE_JOB_NAME:-}"
export RE_JOB_IMAGE="${RE_JOB_IMAGE:-}"
export RE_JOB_BRANCH="${RE_JOB_BRANCH:-master}"
export RE_JOB_SCENARIO="${RE_JOB_SCENARIO:-swift}"
export RE_JOB_ACTION="${RE_JOB_ACTION:-deploy}"
export RE_JOB_FLAVOR="${RE_JOB_FLAVOR:-}"
export RE_JOB_TRIGGER="${RE_JOB_TRIGGER:-PR}"
export RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"

## Functions -----------------------------------------------------------------
source /opt/rpc-openstack/scripts/functions.sh

## OSA MNAIO Vars
export PARTITION_HOST="true"
export NETWORK_BASE="172.29"
export DNS_NAMESERVER="8.8.8.8"
export OVERRIDE_SOURCES="true"
export DEVICE_NAME="vda"
export DEFAULT_NETWORK="eth0"
export DEFAULT_IMAGE="ubuntu-16.04-amd64"
export DEFAULT_KERNEL="linux-image-generic"
export SETUP_HOST="true"
export SETUP_VIRSH_NET="true"
export VM_IMAGE_CREATE="true"
export DEPLOY_OSA="true"
export OSA_BRANCH="${OSA_RELEASE}"
export PRE_CONFIG_OSA="true"
export RUN_OSA="false"
export CONFIGURE_OPENSTACK="false"
export DATA_DISK_DEVICE="sdb"
export CONFIG_PREROUTING="false"
export OSA_PORTS="6080 6082 443 80 8443"
export RPC_BRANCH="${RE_JOB_BRANCH}"
export DEFAULT_MIRROR_HOSTNAME=mirror.rackspace.com
export DEFAULT_MIRROR_DIR=/ubuntu
export INFRA_VM_SERVER_RAM=16384

# ssh command used to execute tests on infra1
export MNAIO_SSH="ssh -ttt -oStrictHostKeyChecking=no root@infra1"
# place variable in file to be sourced by parent calling script 'run'
export MNAIO_VAR_FILE="${MNAIO_VAR_FILE:-/tmp/mnaio_vars}"
echo "export MNAIO_SSH=\"${MNAIO_SSH}\"" > "${MNAIO_VAR_FILE}"

## Main --------------------------------------------------------------------

# capture all RE_ variables
env | grep RE_ | sed 's/^/export /' > /opt/rpc-openstack/RE_ENV

# checkout openstack-ansible-ops
if [ ! -d "/opt/openstack-ansible-ops" ]; then
  git clone --recursive https://github.com/openstack/openstack-ansible-ops /opt/openstack-ansible-ops
else
  pushd /opt/openstack-ansible-ops
    git fetch --all
  popd
fi

# apply various modifications for mnaio
pushd /opt/openstack-ansible-ops/multi-node-aio
  # By default the MNAIO deploys metering services, so we override
  # osa_enable_meter to prevent those services from being deployed.
  sed -i 's/osa_enable_meter: true/osa_enable_meter: false/' playbooks/group_vars/all.yml
popd

# build the multi node aio
pushd /opt/openstack-ansible-ops/multi-node-aio
  # normally we can run ./build.sh by itself but gating environment requires
  # this hack for now, have to set up env before updating cryptography
  # run bootstrap first to set environment up
  ./bootstrap.sh
  # bump up cryptography version to avoid exception detailed in RLM-1104
  pip install cryptography==1.5 --upgrade
  # build the mnaio normally
  ./build.sh
popd
echo "Multi Node AIO setup completed..."

# capture all RE_ variables for push to infra1
env | grep RE_ | sed 's/^/export /' > /opt/rpc-openstack/RE_ENV

# generate infra1 deploy script
cat > /opt/rpc-openstack/deploy-infra1.sh <<EOF
#!/bin/bash
set -evu
# starts the deploy from infra1 vm
source /opt/rpc-openstack/RE_ENV
pushd /opt/rpc-openstack
  scripts/deploy.sh
popd
pushd /opt/rpc-openstack/playbooks
  openstack-ansible openstack-ansible-install.yml
popd
pushd /opt/openstack-ansible/scripts
  python pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml
popd
pushd /opt/openstack-ansible/playbooks
  openstack-ansible setup-everything.yml
popd
EOF

# sync rpc-o to infra and prepare rpc-o configs
set -xe
echo "+---------------- MNAIO RELEASE AND KERNEL --------------+"
lsb_release -a
uname -a
echo "+---------------- MNAIO RELEASE AND KERNEL --------------+"
scp -r -o StrictHostKeyChecking=no /opt/rpc-openstack root@infra1:/opt/
${MNAIO_SSH} <<EOC
  set -xe
  echo "+--------------- INFRA1 RELEASE AND KERNEL --------------+"
  lsb_release -a
  uname -a
  echo "+--------------- INFRA1 RELEASE AND KERNEL --------------+"
  cp /etc/openstack_deploy/user_variables.yml /etc/openstack_deploy/user_variables.yml.bak
  cp -R /opt/openstack-ansible/etc/openstack_deploy /etc
  cp /etc/openstack_deploy/user_variables.yml.bak /etc/openstack_deploy/user_variables.yml
  cp -R /opt/rpc-openstack/etc/openstack_deploy/* /etc/openstack_deploy/
  echo -e '---\nsecurity_rhel7_session_timeout: 1200' | tee /etc/openstack_deploy/user_mnaio_long_hardening_timeout.yml
  chmod +x /opt/rpc-openstack/deploy-infra1.sh
  rm -rf /opt/openstack-ansible
  rm /usr/local/bin/openstack-ansible
EOC

# start the rpc-o install from infra1
${MNAIO_SSH} "/opt/rpc-openstack/deploy-infra1.sh"

echo "MNAIO RPC-O deploy completed..."
