#!/usr/bin/env bash
# Copyright 2014, Rackspace US, Inc.
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
set -euo pipefail

trap "exit -1" ERR

# Track whether linting failed; we don't want to bail on lint failures
failed=0

## Bash Syntax Check ---------------------------------------------------------
echo "Running Bash Syntax Check"

find_bash_scripts(){
  (
    find . -iname '*.sh' #find scripts by name
    egrep -rln '^#!(/usr)?/bin/(env)?/?\s*(ba)?sh' . #find by shebang
  ) |sed 's+^\./++' \
    |sort -u \
    |egrep -v '(^\.git|\.j2$)'
}

while read sfile
do
  echo -en "$sfile\t"
  # run the bash syntax check
  bash -n $sfile \
    && echo "[syntax ok]" \
    || {
      echo "[syntax fail]";
      failed=1;
    }
done <<< "$(find_bash_scripts)"
# use herestring rather than pipe, so that while doesn't create a subshell,
# so failed will still be set outside the loop.

## Ansible Checks ------------------------------------------------------------

# Install the development requirements.
if [[ -f "openstack-ansible/dev-requirements.txt" ]]; then
  pip2 install -r openstack-ansible/dev-requirements.txt || pip install -r openstack-ansible/dev-requirements.txt
else
  pip2 install ansible-lint || pip install ansible-lint
fi

# Run hacking/flake8 check for all python files
# Ignores the following rules due to how ansible modules work in general
#     F403 'from ansible.module_utils.basic import *' used; unable to detect undefined names
#     H303  No wildcard (*) import.
# Excluding our upstream submodule, and our vendored f5 configuration script.
flake8 $(grep -rln -e '^#!/usr/bin/env python' -e '^#!/bin/python' -e '^#!/usr/bin/python' * ) || failed=1

# Perform our simple sanity checks.
pushd rpcd/playbooks

  # Do a basic syntax check on all playbooks and roles.
  echo "Running Ansible Syntax Check"
  # Most versions of ansible will create an implicit localhost
  # entry from an empty inventory. If not, update ansible.
  ansible-playbook -i /dev/null --syntax-check *.yml --list-tasks || failed=1

  # Remove the third-party Ceph roles because they fail ansible-lint
  rm -r roles/ceph-common
  rm -r roles/ceph-mon
  rm -r roles/ceph-osd
  # Perform a lint check on all playbooks and roles.
  echo "Running Ansible Lint Check"
  ansible-lint --version || failed=1
  ansible-lint *.yml || failed=1
popd

if [[ $failed -eq 1 ]]; then
  echo "Failed linting"
  exit -1
fi
