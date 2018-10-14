#!/usr/bin/env bash

# Copyright 2017, Rackspace US, Inc.
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

set -exu

echo "Installing the ELK stack on a RPC-O Multi Node AIO (MNAIO)"

## Vars and Functions --------------------------------------------------------

source "$(readlink -f $(dirname ${0}))/../gating_vars.sh"

source /opt/rpc-openstack/scripts/functions.sh

source "$(readlink -f $(dirname ${0}))/../mnaio_vars.sh"

## Main --------------------------------------------------------------------

${MNAIO_SSH} <<EOS
  cd /opt/rpc-openstack
  openstack-ansible playbooks/elk-deployment.yml
EOS
