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

export BASE_DIR=${PWD}
export PUSH_TO_MIRROR=${PUSH_TO_MIRROR:-no}

## Main ----------------------------------------------------------------------

# bootstrap Ansible and the AIO config
./scripts/bootstrap-ansible.sh

# Only pull from the mirror if these env vars are set
# This enables tests by hand.
if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
    echo "Skipping download from rpc-repo as the REPO_* env vars are not set."
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
    openstack-ansible -vvv -i /opt/inventory \
                      ${BASE_DIR}/scripts/artifacts-building/git/openstackgit-pull-from-mirror.yml
fi

# Fetch all the git repositories
# The openstack-ansible CLI is used to ensure that the library path is set
openstack-ansible -vvv -i /opt/inventory \
                  ${BASE_DIR}/scripts/artifacts-building/git/openstackgit-update.yml

# Only push to the mirror if PUSH_TO_MIRROR is set to "YES"
# This enables PR-based tests which do not change the artifacts
if [[ "$(echo ${PUSH_TO_MIRROR} | tr [a-z] [A-Z])" == "YES" ]]; then
    if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
        echo "Skipping upload to rpc-repo as the REPO_* env vars are not set."
        exit 1
    else
        # Upload the artifacts to rpc-repo
        openstack-ansible -vvv -i /opt/inventory \
                          ${BASE_DIR}/scripts/artifacts-building/git/openstackgit-push-to-mirror.yml
    fi
else
    echo "Skipping upload to rpc-repo as the PUSH_TO_MIRROR env var is not set to 'YES'."
fi
