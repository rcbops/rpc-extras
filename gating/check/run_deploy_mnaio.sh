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

set -exu

echo "Installing RPC-O on a Multi Node AIO (MNAIO)"

## Vars and Functions --------------------------------------------------------

source "$(readlink -f $(dirname ${0}))/../gating_vars.sh"

source /opt/rpc-openstack/scripts/functions.sh

source "$(readlink -f $(dirname ${0}))/../mnaio_vars.sh"

# If there are images available, and this is not the 'deploy' action,
# then we need to run the OSA deploy playbook for some pre-configuration
# before doing the RPC-O bits. The conditional was already evaluated in
# mnaio_vars, so we key off DEPLOY_VMS here.
if [[ "${DEPLOY_VMS}" == "true" ]]; then
  # apply various modifications for mnaio
  pushd /opt/openstack-ansible-ops/multi-node-aio
    # By default the MNAIO deploys metering services, so we override
    # osa_enable_meter to prevent those services from being deployed.
    # TODO(odyssey4me):
    # Remove this once https://review.openstack.org/604034 has merged.
    sed -i 's/osa_enable_meter: true/osa_enable_meter: false/' playbooks/group_vars/all.yml

    export DEPLOY_OSA="true"
    export PRE_CONFIG_OSA="true"

    # Run the initial deployment configuration
    run_mnaio_playbook playbooks/deploy-osa.yml
  popd
else
  # If this is not a deploy test, and the images were used in
  # the 'pre' stage to setup the VM's, then we do not need to
  # execute any more of this script.
  # We implement a simple 5 minute wait to give time for the
  # containers to start in the VM's.
  echo "MNAIO RPC-O deploy completed using images... waiting 5 mins for system startup."
  sleep 300
  exit 0
fi
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
export MNAIO_ANSIBLE_PARAMETERS="-e default_vm_disk_mode=file"
export DEPLOY_MAAS="false"
export GATE_ELK="true"
export DEPLOY_ELK=$(GATE_ELK:-true)
export RUN_ELK=$(GATE_ELK:-true)
# ssh command used to execute tests on infra1
export MNAIO_SSH="ssh -ttt -oStrictHostKeyChecking=no root@infra1"
# place variable in file to be sourced by parent calling script 'run'
export MNAIO_VAR_FILE="${MNAIO_VAR_FILE:-/tmp/mnaio_vars}"
echo "export MNAIO_SSH=\"${MNAIO_SSH}\"" > "${MNAIO_VAR_FILE}"
echo "export RPC_RELEASE=\"${RPC_RELEASE}\"" >> "${MNAIO_VAR_FILE}"
echo "export RPC_PRODUCT_RELEASE=\"${RPC_PRODUCT_RELEASE}\"" >> "${MNAIO_VAR_FILE}"

## Main --------------------------------------------------------------------

# capture all RE_ variables
> /opt/rpc-openstack/RE_ENV
env | grep RE_ | while read -r match; do
  varName=$(echo ${match} | cut -d= -f1)
  echo "export ${varName}='${!varName}'" >> /opt/rpc-openstack/RE_ENV
done

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
  # RI-263 Deploy ELK in the MNAIO gates
  # Enables ELK, OS Profiler and UWSGI Stats
  if [[ $GATE_ELK == "true" ]]; then
    sed -i 's/osa_enable_elk_metrics: false/osa_enable_elk_metrics: true/' playbooks/group_vars/all.yml
    sed -i 's/osa_enable_os_profiler: false/osa_enable_os_profiler: true/' playbooks/group_vars/all.yml
    sed -i 's/osa_enable_uwsgi_stats: false/osa_enable_uwsgi_stats: true/' playbooks/group_vars/all.yml
  fi
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
> /opt/rpc-openstack/RE_ENV
env | grep RE_ | while read -r match; do
  varName=$(echo ${match} | cut -d= -f1)
  echo "export ${varName}='${!varName}'" >> /opt/rpc-openstack/RE_ENV
done

# generate infra1 deploy script
cat > /opt/rpc-openstack/deploy-infra1.sh <<EOF
#!/bin/bash
set -exu
# starts the deploy from infra1 vm
source /opt/rpc-openstack/RE_ENV

pushd /opt/rpc-openstack
  scripts/deploy.sh
popd
pushd /opt/rpc-openstack/playbooks
  /opt/rpc-ansible/bin/ansible-playbook -i 'localhost,' openstack-ansible-install.yml
popd
pushd /opt/openstack-ansible/scripts
  python pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml
popd
pushd /opt/openstack-ansible/playbooks
  # RO-4211
  # Implement debug output for apt so that we can see more information
  # about whether the 'Acquire-by-hash' feature is being used, and what
  # might be causing it to fall back to the old style.
  # This config file should be copied into containers by the lxc_hosts
  # role.
  ansible hosts -m lineinfile -a 'create=yes dest=/etc/apt/apt.conf.d/99debug line="Debug::Acquire::http \"true\";"'
  openstack-ansible setup-hosts.yml setup-infrastructure.yml setup-openstack.yml
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
  echo -e '---\nsecurity_sshd_client_alive_interval: 1200' | tee /etc/openstack_deploy/user_mnaio_long_hardening_timeout.yml
  chmod +x /opt/rpc-openstack/deploy-infra1.sh
  rm -rf /opt/openstack-ansible
EOC

# start the rpc-o install from infra1
${MNAIO_SSH} "/opt/rpc-openstack/deploy-infra1.sh"

echo "MNAIO RPC-O deploy completed..."

if [[ $RE_JOB_ACTION == "deploy" ]]; then
  # run tempest tests on MNAIO for deploy action
  ${MNAIO_SSH} <<EOS
    cd /opt/openstack-ansible
    openstack-ansible -e tempest_run=yes playbooks/os-tempest-install.yml
EOS
fi
