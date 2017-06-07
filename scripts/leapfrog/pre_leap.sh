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

if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/variable-migration.complete" ]]; then
  # Following docs: https://pages.github.rackspace.com/rpc-internal/docs-rpc/rpc-upgrade-internal/rpc-upgrade-v12-v13-perform.html#migrate-variables
  if [[ ! -d variables-backup ]]; then
    mkdir variables-backup
  fi
  pushd variables-backup
    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_extras_variables_migration.complete" ]]; then
      cp /etc/openstack_deploy/user_extras_variables.yml ./
        # Handle the weird newton case
        if [[ ! -f "${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/user_rpco_variables_defaults.yml" ]]; then
           echo -e "---\ndelete_this_line: yes" >> ${RPCO_DEFAULT_FOLDER}/rpcd${RPCD_DEFAULTS}
        fi
        pushd ${RPCO_DEFAULT_FOLDER}/scripts
          ./migrate-yaml.py \
            --defaults ${RPCO_DEFAULT_FOLDER}/rpcd${RPCD_DEFAULTS} \
            --overrides /etc/openstack_deploy/user_extras_variables.yml \
            --output-file ${RPCD_OVERRIDES} \
            --for-testing-take-new-vars-only
        popd
      rm -f /etc/openstack_deploy/user_extras_variables.yml
      log "user_extras_variables_migration" "ok"
    else
      log "user_extras_variables_migration" "skipped"
    fi

    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_variables_migration.complete" ]]; then
      cp /etc/openstack_deploy/user_variables.yml ./
        pushd ${RPCO_DEFAULT_FOLDER}/scripts
          ./migrate-yaml.py \
            --defaults ${RPCO_DEFAULT_FOLDER}/rpcd${OA_DEFAULTS} \
            --overrides /etc/openstack_deploy/user_variables.yml \
            --output-file ${OA_OVERRIDES} \
            --for-testing-take-new-vars-only
        popd
      rm -f /etc/openstack_deploy/user_variables.yml
      log "user_variables_migration" "ok"
    else
      log "user_variables_migration" "skipped"
    fi

    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_secrets_migration.complete" ]]; then
      cp /etc/openstack_deploy/*_secrets.yml ./
      pushd ${RPCO_DEFAULT_FOLDER}/scripts
        python2.7 ./update-yaml.py \
          ${RPCO_DEFAULT_FOLDER}/rpcd${RPCD_SECRETS} \
          /etc/openstack_deploy/user_extras_secrets.yml >> ${RPCD_SECRETS}
      popd
      rm -f /etc/openstack_deploy/user_extras_secrets.yml
      log "user_secrets_migration" "ok"
    else
      log "user_secrets_migration" "skipped"
    fi

    python2.7 ${RPCO_DEFAULT_FOLDER}/openstack-ansible/scripts/pw-token-gen.py \
      --file ${RPCD_SECRETS}
    mv /etc/openstack_deploy/user_secrets.yml /etc/openstack_deploy/user_osa_secrets.yml
    rm -f /etc/openstack_deploy/user_extras_secrets.yml /etc/openstack_deploy/user_secrets.yml
    cp ${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/*defaults* /etc/openstack_deploy
  popd
  log "variable-migration" "ok"
else
  log "variable-migration" "skipped"
fi
