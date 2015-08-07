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
set -ux pipefail

FAILED=0

function run_or_print() {
        command="$@"
        if [ $FAILED -ne 0 ]; then
                echo "  ${command}"
        else
                eval "$command"
                FAILED=$?
                if [ $FAILED -ne 0 ]; then
                    echo "******************** FAILURE ********************"
                    echo "The upgrade script has failed. Please rerun the following task to continue"
                    echo "Failed on task ${command}"
                    echo "Do NOT rerun the upgrade script!"
                    echo "Please execute the remaining tasks:"
                fi
        fi
}

BASE_DIR=$( cd "$( dirname ${0} )" && cd ../ && pwd )
OSAD_DIR="$BASE_DIR/os-ansible-deployment"
RPCD_DIR="$BASE_DIR/rpcd"

# Merge new overrides into existing user_variables before upgrade
# contents of existing user_variables take precedence over new overrides
run_or_print cp ${RPCD_DIR}/etc/openstack_deploy/user_variables.yml /tmp/upgrade_user_variables.yml
run_or_print ${BASE_DIR}/scripts/update-yaml.py /tmp/upgrade_user_variables.yml /etc/rpc_deploy/user_variables.yml
run_or_print mv /tmp/upgrade_user_variables.yml /etc/rpc_deploy/user_variables.yml

# Do the upgrade for os-ansible-deployment components
run_or_print cd ${OSAD_DIR}
run_or_print ${OSAD_DIR}/scripts/run-upgrade.sh

# Prevent the deployment script from re-running the OSAD playbooks
run_or_print export DEPLOY_OSAD="no"

# Do the upgrade for the RPC components
run_or_print source ${OSAD_DIR}/scripts/scripts-library.sh
run_or_print cd ${BASE_DIR}
run_or_print ${BASE_DIR}/scripts/deploy.sh

# the auth_ref on disk is now not usable by the new plugins
run_or_print cd ${RPCD_DIR}/playbooks
run_or_print ansible hosts -m shell -a 'rm /root/.auth_ref.json'

if [ $FAILED -ne 0 ]; then
    echo "******************** FAILURE ********************"
fi
exit $FAILED
