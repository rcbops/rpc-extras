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

# Set this to NO if you do not want to pull any existing data from rpc-repo.
export PULL_FROM_MIRROR=${PULL_FROM_MIRROR:-yes}

# Set this to YES if you want to push any changes made in this job to rpc-repo.
export PUSH_TO_MIRROR=${PUSH_TO_MIRROR:-no}

# The BASE_DIR needs to be set to ensure that the scripts
# know it and use this checkout appropriately.
export BASE_DIR=${PWD}

# We want the role downloads to be done via git
# This ensures that there is no race condition with the artifacts-git job
export ANSIBLE_ROLE_FETCH_MODE="git-clone"

## Main ----------------------------------------------------------------------

# Bootstrap Ansible
./scripts/bootstrap-ansible.sh

# Only pull from the mirror if PULL_FROM_MIRROR is set to "YES"
#
# This should be avoided when used along with PUSH_TO_MIRROR == "YES"
# as it will remove any git repositories that are there for older
# releases. The use-case for this is a repo that changes name or is
# removed from OSA/RPC - for the tag that included this repo to still
# work it must have access to the git repo as it was at the time the
# tag was published.
#
if [[ "$(echo ${PULL_FROM_MIRROR} | tr [a-z] [A-Z])" == "YES" ]]; then
    if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
        echo "Cannot download from rpc-repo as the REPO_* env vars are not set."
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

        # Download the artifacts from rpc-repo
        openstack-ansible -i /opt/inventory \
                          ${BASE_DIR}/scripts/artifacts-building/git/openstackgit-pull-from-mirror.yml \
                          ${ANSIBLE_PARAMETERS}
    fi
else
    echo "Skipping download from rpc-repo as the PULL_FROM_MIRROR env var is not set to 'YES'."
fi

# Fetch all the git repositories
# The openstack-ansible CLI is used to ensure that the library path is set
#
openstack-ansible -i /opt/inventory \
                  ${BASE_DIR}/scripts/artifacts-building/git/openstackgit-update.yml \
                  ${ANSIBLE_PARAMETERS}

# Only push to the mirror if PUSH_TO_MIRROR is set to "YES"
#
# This enables PR-based tests which do not change the artifacts
#
if [[ "$(echo ${PUSH_TO_MIRROR} | tr [a-z] [A-Z])" == "YES" ]]; then
    if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
        echo "Skipping upload to rpc-repo as the REPO_* env vars are not set."
        exit 1
    else
        # Upload the artifacts to rpc-repo
        openstack-ansible -i /opt/inventory \
                          ${BASE_DIR}/scripts/artifacts-building/git/openstackgit-push-to-mirror.yml \
                          ${ANSIBLE_PARAMETERS}
    fi
else
    echo "Skipping upload to rpc-repo as the PUSH_TO_MIRROR env var is not set to 'YES'."
fi
