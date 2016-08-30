#!/usr/bin/env bash
# Copyright 2014, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# (c) 2015, Nolan Brubaker <nolan.brubaker@rackspace.com>

set -eux -o pipefail

BASE_DIR=$( cd "$( dirname ${0} )" && cd ../ && pwd )
OA_DIR="$BASE_DIR/openstack-ansible"
RPCD_DIR="$BASE_DIR/rpcd"
OSA_VARS="/etc/openstack_deploy/user_osa_variables_defaults.yml"

# TASK #1
# Bug: https://github.com/rcbops/rpc-openstack/issues/1345
# Issue: horizon-extensions now gets pulled from a different location; the
#        git cache on the repo_all containers needs to be deleted so we can
#        grab the new repo.  Failing to do this will cause repo-install.yml
#        to fail to run.
cd ${RPCD_DIR}/playbooks
ansible -m file -a "path=/var/www/repo/openstackgit/horizon-extensions state=absent" repo_all

# TASK #2
# Bug: https://github.com/rcbops/u-suk-dev/issues/215
# issue: Enable the Horizon panels for LBaaSv2 if the environment has LBaaSv2
#        enabled already. Check for anything matching "LoadBalancerPluginv2"
#        in the OSA config and enable the Horizon panels via the RPC defaults
#        config.
if grep -q "LoadBalancerPluginv2" /etc/openstack_deploy/user_variables.yml ; then
    if ! grep -q "^horizon_enable_neutron_lbaas" "${OSA_VARS}" ; then
        echo "horizon_enable_neutron_lbaas: True" | tee -a "${OSA_VARS}"
    fi
fi
