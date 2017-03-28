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

export DEPLOY_AIO=yes
export ANSIBLE_ROLE_FETCH_MODE=git-clone
export PUSH_TO_MIRROR=${PUSH_TO_MIRROR:-no}

## Functions ----------------------------------------------------------------------

function patch_all_roles {
    for role_name in *; do
        cd /etc/ansible/roles/$role_name;
        git am <  /opt/rpc-openstack/scripts/artifacts-building/containers/patches/$role_name;
    done
}

function ansible_tag_filter {
    TAGS=$($1 --list-tags | grep -o '\s\[.*\]' | sed -e 's|,|\n|g' -e 's|\[||g' -e 's|\]||g')
    echo "TAG LIST IS $TAGS"
    INCLUDE_TAGS_LIST=$(echo -e "${TAGS}" | grep -w "$2")
    INCLUDE_TAGS=$(echo "always" ${INCLUDE_TAGS_LIST} | sed 's|\s|,|g')
    echo "INCLUDED TAGS: ${INCLUDE_TAGS}"
    SKIP_TAGS_LIST=$(echo -e "${TAGS}" | grep -w "$3" )
    SKIP_TAGS=$(echo ${SKIP_TAGS_LIST} | sed 's|\s|,|g')
    echo "SKIPPED TAGS: ${SKIP_TAGS}"
    $1 --tags "${INCLUDE_TAGS}" --skip-tags "${SKIP_TAGS}"
}

## Main ----------------------------------------------------------------------

# Ensure no role is present before starting
rm -rf /etc/ansible/roles/

# Ensure no remnants (not necessary if ephemeral host, but useful for dev purposes
rm -f /opt/list

# bootstrap Ansible and the AIO config
cd /opt/rpc-openstack
./scripts/bootstrap-ansible.sh
./scripts/bootstrap-aio.sh

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
echo "rpc_release: $(/opt/rpc-openstack/scripts/artifacts-building/derive-artifact-version.py)" >> /etc/openstack_deploy/user_rpco_variables_overrides.yml
cd scripts/artifacts-building/
cp user_*.yml /etc/openstack_deploy/

# Prepare role patching
git config --global user.email "rcbops@rackspace.com"
git config --global user.name "RCBOPS gating"

# TEMP WORKAROUND: CHECKOUT the version you need before patching!
pushd /etc/ansible/roles/os_keystone
git fetch --all
git checkout stable/newton
popd

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
openstack-ansible /opt/rpc-openstack/rpcd/playbooks/configure-apt-sources.yml -e "host_ubuntu_repo=http://mirror.rackspace.com/ubuntu"

# Setup the host
openstack-ansible setup-hosts.yml --limit lxc_hosts,hosts

# Move back to artifacts-building dir
cd /opt/rpc-openstack/scripts/artifacts-building/

# Build it!
openstack-ansible containers/artifact-build-chroot.yml -e role_name=pip_install -e image_name=default -v
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=elasticsearch -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=galera_server -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=kibana -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=logstash -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=memcached_server -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_cinder -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_glance -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_heat -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_horizon -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_ironic -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_keystone -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_neutron -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_nova -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_swift -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_tempest -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=rabbitmq_server -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=repo_server -v" "install" "config"
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=rsyslog_server -v" "install" "config"

# Only push to the mirror if PUSH_TO_MIRROR is set to "YES"
# This enables PR-based tests which do not change the artifacts
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
  fi
else
  echo "Skipping upload to rpc-repo as the PUSH_TO_MIRROR env var is not set to 'YES'."
fi
