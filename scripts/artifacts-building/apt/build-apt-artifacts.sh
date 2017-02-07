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

set -e
set -o pipefail

## Vars ----------------------------------------------------------------------

# The BASE_DIR needs to be set to ensure that the scripts
# know it and use this checkout appropriately.
export BASE_DIR=${PWD}

# We want the role downloads to be done via git
# This ensures that there is no race condition with the artifacts-git job
export ANSIBLE_ROLE_FETCH_MODE="git-clone"

export ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY:--v}
export RPC_ARTIFACTS_FOLDER=${RPC_ARTIFACTS_FOLDER:-/var/www/artifacts}
export RPC_ARTIFACTS_PUBLIC_FOLDER=${RPC_ARTIFACTS_PUBLIC_FOLDER:-/var/www/repo}
export RPC_REPO_BRANCH=${RPC_REPO_BRANCH:-artifacts-14.0}

## Main ----------------------------------------------------------------------

if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
  echo "ERROR: The required REPO_ environment variables are not set."
  exit 1
elif [ -z ${GPG_PRIVATE+x} ] || [ -z ${GPG_PUBLIC+x} ]; then
  echo "ERROR: The required GPG_ environment variables are not set."
  exit 1
fi

# Jenkins uses a weird checkout mechanism which does not checkout
# the local branch, but instead the latest SHA on the branch directly.
# This breaks the way we derive the branch, so here we check it out
# in the way we expect it.
git checkout ${RPC_REPO_BRANCH}

#Output some debug information
echo "GIT_TAG: $(git describe --tags --abbrev=0)"
echo "GIT_BRANCH: $(git branch --contains $(git rev-parse HEAD) | grep ^\* | sed 's/^\* //')"

# Ensure that the openstack-ansible submodule is updated
git submodule init
git submodule update

# The derive-artifact-version.py script expects the git clone to
# be at /opt/rpc-openstack, so we link the current folder there.
ln -sfn ${PWD} /opt/rpc-openstack

# Install Ansible
./scripts/bootstrap-ansible.sh

# Ensure the required folders are present
mkdir -p ${RPC_ARTIFACTS_FOLDER}
mkdir -p ${RPC_ARTIFACTS_PUBLIC_FOLDER}

set +x
# Setup the repo key for package download/upload
REPO_KEYFILE=~/.ssh/repo.key
cat $REPO_USER_KEY > ${REPO_KEYFILE}
chmod 600 ${REPO_KEYFILE}

# Setup the GPG key for package signing
cat $GPG_PRIVATE > ${RPC_ARTIFACTS_FOLDER}/aptly.private.key
cat $GPG_PUBLIC > ${RPC_ARTIFACTS_FOLDER}/aptly.public.key
set -x

# Ensure that the repo server public key is a known host
grep "${REPO_HOST}" ~/.ssh/known_hosts || echo "${REPO_HOST} $(cat $REPO_HOST_PUBKEY)" >> ~/.ssh/known_hosts

#Append host to [mirrors] group
echo '[mirrors]' > /opt/inventory
echo "repo ansible_host=${REPO_HOST} ansible_user=${REPO_USER} ansible_ssh_private_key_file='${REPO_KEYFILE}' " >> /opt/inventory

# Execute the playbooks
cd ${BASE_DIR}/scripts/artifacts-building/apt
ansible-playbook aptly-pre-install.yml ${ANSIBLE_VERBOSITY}
ansible-playbook aptly-all.yml -i /opt/inventory ${ANSIBLE_VERBOSITY}

# List the contents
ls -R ${RPC_ARTIFACTS_FOLDER}
