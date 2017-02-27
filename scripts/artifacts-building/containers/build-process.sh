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

# bootstrap Ansible and the AIO config
cd /opt/rpc-openstack
./scripts/bootstrap-ansible.sh
./scripts/bootstrap-aio.sh

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
openstack-ansible setup-hosts.yml --limit lxc_hosts,hosts

# Move back to artifacts-building dir
cd /opt/rpc-openstack/scripts/artifacts-building/

# Build it!
openstack-ansible containers/artifact-build-chroot.yml -e role_name=pip_install -e image_name=default -v
ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=galera_server -v" "install" "config"
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

# Ensure no remnants (not necessary if ephemeral host, but useful for dev purposes
rm -f /tmp/list

if [ -z ${REPO_KEY+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_USER+x} ]; then
    echo "Skipping upload to rpc-repo as the REPO_* env vars are not set."
    exit 1
else
    # Prep the ssh key for uploading to rpc-repo
    mkdir -p ~/.ssh/
    set +x
    key=~/.ssh/repo.key
    echo "-----BEGIN RSA PRIVATE KEY-----" > $key
    echo "$REPO_KEY" \
      |sed -e 's/\s*-----BEGIN RSA PRIVATE KEY-----\s*//' \
           -e 's/\s*-----END RSA PRIVATE KEY-----\s*//' \
           -e 's/ /\n/g' >> $key
    echo "-----END RSA PRIVATE KEY-----" >> $key
    chmod 600 ${key}
    set -x
    #Append host to [mirrors] group
    echo '[mirrors]' > /opt/inventory
    echo "repo ansible_host=${REPO_HOST} ansible_user=${REPO_USER} ansible_ssh_private_key_file='${key}' " >> /opt/inventory

    # As we don't have access to the public key in this job
    # we need to disable host key checking.
    export ANSIBLE_HOST_KEY_CHECKING=False

    # Ship it!
    openstack-ansible containers/artifact-upload.yml -i /opt/inventory -v
fi
