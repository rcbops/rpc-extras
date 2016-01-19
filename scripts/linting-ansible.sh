#!/usr/bin/env bash
# Copyright 2015, Rackspace US, Inc.
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

## Main ----------------------------------------------------------------------
if [[ -z "$VIRTUAL_ENV" ]] ; then
    echo "WARNING: Not running hacking inside a virtual environment."
fi

pushd rpcd/playbooks/
  echo "Running ansible-playbook syntax check"
  # Do a basic syntax check on all playbooks and roles.
  ansible-playbook -i 'localhost,' --syntax-check *.yml --list-tasks
  # Perform a lint check on all playbooks and roles.
  ansible-lint --version
  # Skip ceph roles because they're submodules and not ours to lint
  # NOTE(sigmavirus24): If
  # https://github.com/willthames/ansible-lint/issues/80 is accepted and
  # merged, get rid of these awful hacks around removing directories and
  # re-placing them.
  rm -r roles/ceph-common
  rm -r roles/ceph-mon
  rm -r roles/ceph-osd
  echo "Running ansible-lint"
  # Lint playbooks and roles
  ansible-lint *.yml
  # Revert changes to deleting submodules
  git checkout .
  # Re-clone the submodules for the next run
  git submodule update >/dev/null
popd
