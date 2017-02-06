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

## Main ----------------------------------------------------------------------

# bootstrap Ansible and the AIO config
cd /opt/rpc-openstack
./scripts/bootstrap-ansible.sh
./scripts/bootstrap-aio.sh

# Set override vars for the artifact build
echo "rpc_release: $(/opt/rpc-openstack/scripts/artifacts-building/derive-artifact-version.py)" >> /etc/openstack_deploy/user_rpco_variables_overrides.yml
echo "repo_build_wheel_selective: no" >> /etc/openstack_deploy/user_osa_variables_overrides.yml
echo "repo_build_venv_selective: no" >> /etc/openstack_deploy/user_osa_variables_overrides.yml

# Setup the repo container and build the artifacts
cd /opt/rpc-openstack/openstack-ansible/playbooks
openstack-ansible setup-hosts.yml -e container_group=repo_all
openstack-ansible repo-install.yml

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

  # Upload the artifacts to rpc-repo
  openstack-ansible -vvv -i /opt/inventory \
                    /opt/rpc-openstack/scripts/artifacts-building/python/upload-python-artifacts.yml \
                    -e repo_container_name=$(lxc-ls '.*_repo_' '|' head -n1)
fi
