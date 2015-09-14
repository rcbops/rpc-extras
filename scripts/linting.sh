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

## Main ----------------------------------------------------------------------
echo "Running Basic Ansible Lint Check"


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
  # Put local inventory in a var so we're not polluting the file system too much
  LOCAL_INVENTORY='[all]\nlocalhost ansible_connection=local'

  # Do a basic syntax check on all playbooks and roles.
  echo "Running Syntax Check"
  ansible-playbook -i <(echo $LOCAL_INVENTORY) --syntax-check *.yml --list-tasks || failed=1

  # Perform a lint check on all playbooks and roles.
  echo "Running Lint Check"
  ansible-lint --version || failed=1
  ansible-lint *.yml || failed=1
popd

if [[ $failed -eq 1 ]]; then
  echo "Failed linting"
  exit -1
fi
