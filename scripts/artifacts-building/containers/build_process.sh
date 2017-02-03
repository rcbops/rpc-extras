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
  for role_name in *;
  do 
    cd /etc/ansible/roles/$role_name;
    git am <  /opt/rpc-openstack/scripts/artifacts-building/patches/$role_name;
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
  echo "SKIPED TAGS: ${SKIP_TAGS}"
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

pushd scripts/artifacts-building/
cp user_*.yml /etc/openstack_deploy/

# Patch the roles
cd containers/patches/
patch_all_roles

# Run playbooks
pushd /opt/rpc-openstack/openstack-ansible/playbooks
openstack-ansible setup-hosts.yml #--limit lxc_hosts,hosts #TODO(evrardjp) IMPROVE system by limiting to proper hosts

# Move back to artifacts-building dir
popd

ansible_tag_filter "openstack-ansible containers/artifact-build-chroot.yml -e role_name=os_keystone -v" "install" "config"
