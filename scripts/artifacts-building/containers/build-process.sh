#!/usr/bin/env bash
# Copyright 2014-2017 , Rackspace US, Inc.
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

## Vars ----------------------------------------------------------------------

# To provide flexibility in the jobs, we have the ability to set any
# parameters that will be supplied on the ansible-playbook CLI.
export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:--v}

# Set this to YES if you want to replace any existing artifacts for the current
# release with those built in this job.
export REPLACE_ARTIFACTS=${REPLACE_ARTIFACTS:-no}

# Set this to YES if you want to push any changes made in this job to rpc-repo.
export PUSH_TO_MIRROR=${PUSH_TO_MIRROR:-no}

# The BASE_DIR needs to be set to ensure that the scripts
# know it and use this checkout appropriately.
export BASE_DIR=${PWD}

# We want the role downloads to be done via git
# This ensures that there is no race condition with the artifacts-git job
export ANSIBLE_ROLE_FETCH_MODE="git-clone"

## Functions ----------------------------------------------------------------------

function patch_all_roles {
    for role_name in *; do
        cd /etc/ansible/roles/$role_name;
        git am <  /opt/rpc-openstack/scripts/artifacts-building/containers/patches/$role_name;
    done
}

## Main ----------------------------------------------------------------------

# Ensure no remnants (not necessary if ephemeral host, but useful for dev purposes
rm -f /opt/list

# The derive-artifact-version.py script expects the git clone to
# be at /opt/rpc-openstack, so we link the current folder there.
ln -sfn ${PWD} /opt/rpc-openstack

# Bootstrap Ansible and the AIO config
cd /opt/rpc-openstack
./scripts/bootstrap-ansible.sh
./scripts/bootstrap-aio.sh

# Figure out the release version
export RPC_RELEASE="$(/opt/rpc-openstack/scripts/artifacts-building/derive-artifact-version.py)"

# Force replace -> PUSH
if [[ "$(echo ${REPLACE_ARTIFACTS} | tr [a-z] [A-Z])" == "YES" ]]; then
  export PUSH_TO_MIRROR="YES"
fi
# No artifact for this release -> PUSH
if curl http://rpc-repo.rackspace.com/meta/1.0/index-system | grep "${RPC_RELEASE}"; then
  export PUSH_TO_MIRROR="YES"
fi

# Remove the RPC-O default configurations that are necessary
# for deployment, but cause the build to break due to the fact
# that they require the container artifacts to be available,
# but those are not yet built.
sed -i.bak '/lxc_image_cache_server: /d' /etc/openstack_deploy/user_osa_variables_defaults.yml
sed -i.bak '/lxc_cache_default_variant: /d' /etc/openstack_deploy/user_osa_variables_defaults.yml
sed -i.bak '/lxc_cache_download_template_extra_options: /d' /etc/openstack_deploy/user_osa_variables_defaults.yml
sed -i.bak '/lxc_container_variant: /d' /etc/openstack_deploy/user_osa_variables_defaults.yml
sed -i.bak '/lxc_container_download_template_extra_options: /d' /etc/openstack_deploy/user_osa_variables_defaults.yml

# Set override vars for the artifact build
echo "rpc_release: ${RPC_RELEASE}" >> /etc/openstack_deploy/user_rpco_variables_overrides.yml
cd scripts/artifacts-building/
cp user_*.yml /etc/openstack_deploy/

# Prepare role patching
git config --global user.email "rcbops@rackspace.com"
git config --global user.name "RCBOPS gating"

# Patch the roles
cd containers/patches/
patch_all_roles

# Run playbooks
cd /opt/rpc-openstack/openstack-ansible/playbooks

# The host must only have the base Ubuntu repository configured.
# All updates (security and otherwise) must come from the RPC-O apt artifacting.
# The host sources are modified to ensure that when the containers are prepared
# they have our mirror included as the default. This happens because in the
# lxc_hosts role the host apt sources are copied into the container cache.
openstack-ansible /opt/rpc-openstack/rpcd/playbooks/configure-apt-sources.yml \
                  -e "host_ubuntu_repo=http://mirror.rackspace.com/ubuntu" \
                  ${ANSIBLE_PARAMETERS}

# Setup the host
openstack-ansible setup-hosts.yml --limit lxc_hosts,hosts

# Move back to artifacts-building dir
cd /opt/rpc-openstack/scripts/artifacts-building/

# Build the base container
openstack-ansible containers/artifact-build-chroot.yml \
                  -e role_name=pip_install \
                  -e image_name=default \
                  ${ANSIBLE_PARAMETERS}

# Build the list of roles to build containers for
role_list=""
role_list="${role_list} os_horizon os_ironic os_keystone os_neutron os_nova"
role_list="${role_list} os_swift os_tempest rabbitmq_server repo_server"
role_list="${role_list} memcached_server os_cinder os_glance os_heat"
role_list="${role_list} rsyslog_server"
role_list="${role_list} elasticsearch kibana logstash"

# Build all the containers
for cnt in ${role_list}; do
  openstack-ansible containers/artifact-build-chroot.yml \
                    -e role_name=${cnt} \
                    ${ANSIBLE_PARAMETERS}
done

# test one container build contents
openstack-ansible containers/test-built-container.yml
openstack-ansible containers/test-built-container-idempotency-test.yml | tee /tmp/output.txt; grep -q 'changed=0.*failed=0' /tmp/output.txt && { echo 'Idempotence test: pass';  } || { echo 'Idempotence test: fail' && exit 1; }

if [[ "$(echo ${PUSH_TO_MIRROR} | tr [a-z] [A-Z])" == "YES" ]]; then
  if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
    echo "Skipping upload to rpc-repo as the REPO_* env vars are not set."
    exit 1
  else
    # Prep the ssh key for uploading to rpc-repo
    mkdir -p ~/.ssh/
    set +x
    REPO_KEYFILE=~/.ssh/repo.key
    cat $REPO_USER_KEY > ${REPO_KEYFILE}
    chmod 600 ${REPO_KEYFILE}
    set -x

    # Ensure that the repo server public key is a known host
    grep "${REPO_HOST}" ~/.ssh/known_hosts || echo "${REPO_HOST} $(cat $REPO_HOST_PUBKEY)" >> ~/.ssh/known_hosts

    # Create the Ansible inventory for the upload
    echo '[mirrors]' > /opt/inventory
    echo "repo ansible_host=${REPO_HOST} ansible_user=${REPO_USER} ansible_ssh_private_key_file='${REPO_KEYFILE}' " >> /opt/inventory

    # Ship it!
    openstack-ansible containers/artifact-upload.yml -i /opt/inventory -v

    # test the uploaded metadata: fetching the metadata file, fetching a
    # container, and checking integrity of the downloaded artifact.
    openstack-ansible containers/test-uploaded-container-metadata.yml -v
  fi
else
  echo "Skipping upload to rpc-repo as the PUSH_TO_MIRROR env var is not set to 'YES'."
fi

