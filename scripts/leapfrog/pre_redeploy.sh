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
#
# (c) 2017, Jean-Philippe Evrard <jean-philippe.evrard@rackspace.co.uk>

## Shell Opts ----------------------------------------------------------------
set -e -u -x
set -o pipefail

notice "Pre redeploy steps"
pushd ${LEAPFROG_DIR}
    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/variable-migration.complete" ]]; then
        # Following docs: https://pages.github.rackspace.com/rpc-internal/docs-rpc/rpc-upgrade-internal/rpc-upgrade-v12-v13-perform.html#migrate-variables
        if [[ ! -d variables-backup ]]; then
            mkdir variables-backup
        fi
        pushd variables-backup
            if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_extras_variables_migration.complete" ]]; then
                cp /etc/openstack_deploy/user_extras_variables.yml ./
                pushd ${RPCO_DEFAULT_FOLDER}/scripts
                    "${RPCO_DEFAULT_FOLDER}"/scripts/migrate-yaml.py ${AUTOMATIC_VAR_MIGRATE_FLAG:-''} \
                        --defaults "${RPCD_DIR}${RPCD_DEFAULTS}" \
                        --overrides /etc/openstack_deploy/user_extras_variables.yml \
                        --output-file ${RPCD_OVERRIDES}
                    rm -f /etc/openstack_deploy/user_extras_variables.yml
                popd
                rm -f /etc/openstack_deploy/user_extras_variables.yml
                log "user_extras_variables_migration" "ok"
            else
                log "user_extras_variables_migration" "skipped"
            fi

            if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_variables_migration.complete" ]]; then
                cp /etc/openstack_deploy/user_variables.yml ./
                pushd ${RPCO_DEFAULT_FOLDER}/scripts
                    "${RPCO_DEFAULT_FOLDER}"/scripts/migrate-yaml.py ${AUTOMATIC_VAR_MIGRATE_FLAG:-''} \
                        --defaults "${RPCD_DIR}${OA_DEFAULTS}" \
                        --overrides /etc/openstack_deploy/user_variables.yml \
                        --output-file ${OA_OVERRIDES}
                    rm -f /etc/openstack_deploy/user_variables.yml
                popd
                rm -f /etc/openstack_deploy/user_variables.yml
                log "user_variables_migration" "ok"
            else
                log "user_variables_migration" "skipped"
            fi

            if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_secrets_migration.complete" ]]; then
                cp /etc/openstack_deploy/*_secrets.yml ./
                pushd ${RPCO_DEFAULT_FOLDER}
                    scripts/update-secrets.sh
                    if [[ -f "/etc/openstack_deploy/user_secrets.yml" ]]; then
                        mv /etc/openstack_deploy/user_secrets.yml \
                           /etc/openstack_deploy/user_osa_secrets.yml
                    fi
                popd
                rm -f /etc/openstack_deploy/user_extras_secrets.yml
                log "user_secrets_migration" "ok"
                cp -a ${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/*defaults* /etc/openstack_deploy
            else
                log "user_secrets_migration" "skipped"
            fi
        popd
        log "variable-migration" "ok"
    else
        log "variable-migration" "skipped"
    fi
    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/rebootstrap-ansible-for-rpc.complete" ]]; then
        pushd ${RPCO_DEFAULT_FOLDER}
            ansible-galaxy install -r ansible-role-requirements.yml
            sed -i "s|GROUP_VARS_PATH=.*|GROUP_VARS_PATH=\"\${GROUP_VARS_PATH:-${RPCO_DEFAULT_FOLDER}/openstack-ansible/playbooks/inventory/group_vars/:${RPCO_DEFAULT_FOLDER}/group_vars/:/etc/openstack_deploy/group_vars/}\"|" /usr/local/bin/openstack-ansible.rc
            sed -i "s|HOST_VARS_PATH=.*|HOST_VARS_PATH=\"\${HOST_VARS_PATH:-${RPCO_DEFAULT_FOLDER}/openstack-ansible/playbooks/inventory/host_vars/:${RPCO_DEFAULT_FOLDER}/host_vars/:/etc/openstack_deploy/host_vars/}\"|" /usr/local/bin/openstack-ansible.rc
            source /usr/local/bin/openstack-ansible.rc
        popd
        log "rebootstrap-ansible-for-rpc" "ok"
    fi
popd
