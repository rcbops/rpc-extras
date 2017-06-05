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

ansible-galaxy install -r ansible-role-requirements.yml --force -p rpcd/playbooks/roles
pushd rpcd/playbooks/
  # NOTE(cloudnull): Gather the playbooks for lint checks skipping maas. The
  #                  MaaS Playbook is skipped because it's included and not
  #                  present on the system until after ansible is bootstrapped.
  PLAYBOOKS="$(ls -1 *.yml | grep -v maas) "
  echo "Running ansible-playbook syntax check"
  # Do a basic syntax check on all playbooks and roles.
  ansible-playbook -i 'localhost,' --syntax-check ${PLAYBOOKS} --list-tasks
  # Perform a lint check on all playbooks and roles.
  ansible-lint --version
  echo "Running ansible-lint"
  # Lint playbooks and roles while skipping the ceph-* roles. They are not
  # ours and so we do not wish to lint them and receive errors about code we
  # do not maintain.
  ansible-lint  ${PLAYBOOKS} --exclude ~/.ansible/roles/ceph.ceph-common \
                             --exclude ~/.ansible/roles/ceph.ceph-mon \
                             --exclude ~/.ansible/roles/ceph.ceph-osd \
                             --exclude roles/ceph.ceph-common \
                             --exclude roles/ceph.ceph-mon \
                             --exclude roles/ceph.ceph-osd
popd
