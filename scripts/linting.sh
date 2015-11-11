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

# linting is done in a diferent directory
sed -i 's/\/opt/\/home\/travis\/build\/rcbops/g' ansible-role-requirements.yml
sed -i 's/\/opt/\/home\/travis\/build\/rcbops/g' rpcd/playbooks/repo-fetcher.yml

# we need ansible to fetch upstream openstack-ansible
pip2 install --force-reinstall 'ansible===1.9.4'
ansible-playbook -i <(echo '[all]\nlocalhost ansible_connection=local') rpcd/playbooks/repo-fetcher.yml

ansible-galaxy install --role-file=ansible-role-requirements.yml --ignore-errors --force

python -m tox
