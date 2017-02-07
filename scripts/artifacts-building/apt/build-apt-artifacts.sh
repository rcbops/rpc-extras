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

export ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY:--v}
export RPC_ARTIFACTS_FOLDER=${RPC_ARTIFACTS_FOLDER:-/var/www/artifacts}
export RPC_ARTIFACTS_PUBLIC_FOLDER=${RPC_ARTIFACTS_PUBLIC_FOLDER:-/var/www/repo}

## Main ----------------------------------------------------------------------

if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
  echo "ERROR: The required REPO_ environment variables are not set."
  exit 1
elif [ -z ${GPG_PRIVATE+x} ] || [ -z ${GPG_PUBLIC+x} ]; then
  echo "ERROR: The required GPG_ environment variables are not set."
  exit 1
fi

cd scripts/artifacts-building/apt
mkdir -p ~/.ssh/
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

# Install Ansible
apt-get update
xargs apt-get install -y < bindep.txt
curl https://bootstrap.pypa.io/get-pip.py | python
pip install ansible==2.2

#Append host to [mirrors] group
echo '[mirrors]' > /opt/inventory
echo "repo ansible_host=${REPO_HOST} ansible_user=${REPO_USER} ansible_ssh_private_key_file='${REPO_KEYFILE}' " >> /opt/inventory

# Execute the playbooks
ansible-playbook aptly-pre-install.yml ${ANSIBLE_VERBOSITY}
ansible-playbook aptly-all.yml -i inventory ${ANSIBLE_VERBOSITY}

# List the contents
ls -R ${RPC_ARTIFACTS_FOLDER}
