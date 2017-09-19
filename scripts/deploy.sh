#!/usr/bin/env bash
# Copyright 2014-2017, Rackspace US, Inc.
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

set -e -u -x
set -o pipefail

## Functions -----------------------------------------------------------------
export ANSIBLE_TIMEOUT=120
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

## Main ----------------------------------------------------------------------

if [[ "$DEPLOY_AIO" != "yes" ]] && [[ "$DEPLOY_HARDENING" != "yes" ]]; then
  echo "** DEPLOY_HARDENING should no longer be used **"
  echo "To disable security hardening, please add the following line to"
  echo "/etc/openstack_deploy/user_osa_variables_overrides.yml and then"
  echo "re-run this script:"
  echo ""
  echo "apply_security_hardening: false"
  exit 1
fi

# Bootstrap Ansible
source "$(dirname "${0}")/bootstrap-ansible.sh"

# Install the Ansible Run Analyser callback. This is used to gather task failure
# information in gate jobs.
if [[ "${DEPLOY_ARA}" == "yes" ]]; then
  /opt/ansible-runtime/bin/pip install --upgrade-strategy only-if-needed ara
  export ANSIBLE_CALLBACK_PLUGINS="/etc/ansible/roles/plugins/callback:/opt/ansible-runtime/lib/python2.7/site-packages/ara/plugins/callbacks"
fi

# bootstrap the AIO
if [[ "${DEPLOY_AIO}" == "yes" ]]; then

  # execute the AIO configuration bootstrap
  source "$(dirname "${0}")/bootstrap-aio.sh"

  # set the ansible inventory hostname to the host's name
  sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/openstack_user_config.yml
  sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/conf.d/*.yml

fi

# Configure for multi-node AIO
if [[ "${CONFIGURE_MNAIO}" == "yes" ]]; then
  source "$(dirname "${0}")/configure-multi-node-aio.sh"
fi

# move OSA secrets to correct locations
if [[ ! -f /etc/openstack_deploy/user_osa_secrets.yml ]] && [[ -f /etc/openstack_deploy/user_secrets.yml ]]; then
  mv /etc/openstack_deploy/user_secrets.yml /etc/openstack_deploy/user_osa_secrets.yml
fi

# update the RPC-O secrets
bash ${BASE_DIR}/scripts/update-secrets.sh

# ensure all needed passwords and tokens are generated
${OA_DIR}/scripts/pw-token-gen.py --file /etc/openstack_deploy/user_osa_secrets.yml
${OA_DIR}/scripts/pw-token-gen.py --file $RPCD_SECRETS

# ensure that the ELK containers aren't created if they're not
# going to be used
# NOTE: this needs to happen before ansible/openstack-ansible is first run
if [[ "${DEPLOY_ELK}" != "yes" ]]; then
  rm -f /etc/openstack_deploy/env.d/{elasticsearch,logstash,kibana}.yml
fi

# Copy the current default user-space extra-vars files
copy_default_user_space_files

cd ${RPCD_DIR}/playbooks

# begin the openstack installation
if [[ "${DEPLOY_OA}" == "yes" ]]; then

  # This deploy script is also used for minor upgrades (within an openstack release)
  # Some versions of liberty deploy pip lockdown to the repo server, in order for an
  # upgrade to succeed the pip config must be removed so that repo builds have
  # access to external repos.
  # Issue tracking upstream fix: https://github.com/rcbops/rpc-openstack/issues/1028
  ansible repo_all -m file -a 'name=/root/.pip state=absent' 2>/dev/null ||:

  cd ${OA_DIR}/playbooks/

  if apt_artifacts_available; then
    # The hosts must only have the base Ubuntu repository configured.
    # All updates (security and otherwise) must come from the RPC-O apt artifacting.
    run_ansible ${RPCD_DIR}/playbooks/configure-apt-sources.yml
  fi

  # NOTE(mhayden): V-38642 must be skipped when using an apt repository with
  # unsigned/untrusted packages.
  # NOTE(mhayden): V-38660 halts the playbook run when it finds SNMP v1/2
  # configurations on a server. RPC has these configurations applied, so this
  # task must be skipped.
  if [[ ${UNAUTHENTICATED_APT} == "yes" && ${DEPLOY_HARDENING} == "yes" ]]; then
    run_ansible setup-hosts.yml --skip-tags=V-38462,V-38660
  else
    run_ansible setup-hosts.yml --skip-tags=V-38660
  fi

  if apt_artifacts_available; then
    # The containers must only have the base Ubuntu repository configured.
    # All updates (security and otherwise) must come from the RPC-O apt artifacting.
    # The container artifacts will have mirror.rackspace.com configured as the source,
    # but in a CDC there may be a local mirror that's used instead. This ensures that
    # after the container is built it is reconfigured to use that local mirror. If
    # this is not done then the apt-get update tasks will fail when we try to deploy
    # the services.
    run_ansible ${RPCD_DIR}/playbooks/configure-apt-sources.yml -e apt_target_group=all_containers
  fi

  if [[ "$DEPLOY_CEPH" == "yes" ]]; then
    pushd ${RPCD_DIR}/playbooks/
      run_ansible ceph-all.yml
    popd
  fi


  # setup infrastructure
  run_ansible unbound-install.yml

  # If python artifacts are available, use the staging process.
  # If they are not, then use the repo build process.
  if git_artifacts_available && python_artifacts_available; then
    run_ansible ${RPCD_DIR}/playbooks/stage-python-artifacts.yml
    run_ansible repo-server.yml
  else
    run_ansible repo-install.yml
  fi

  run_ansible haproxy-install.yml
  run_ansible memcached-install.yml
  run_ansible galera-install.yml
  run_ansible rabbitmq-install.yml
  run_ansible etcd-install.yml
  run_ansible utility-install.yml
  run_ansible rsyslog-install.yml

  # setup openstack
  run_ansible setup-openstack.yml

  if [[ "${DEPLOY_TEMPEST}" == "yes" ]]; then
    # Deploy tempest
    run_ansible ${BASE_DIR}/scripts/run_tempest.yml
  fi

  if [[ "${DEPLOY_RALLY}" == "yes" ]]; then
    # Deploy rally
    run_ansible os-rally-install.yml
  fi

  if [[ "${DEPLOY_UPGRADE_TOOLS}" == "yes" ]]; then
    # Deploy upgrade tools which will exercise the code paths, perform backups,
    #  and provide reports on the environment health.
    run_ansible ${BASE_DIR}/rpcd/playbooks/rpc-pre-upgrade.yml
    run_ansible ${BASE_DIR}/rpcd/playbooks/rpc-post-upgrade.yml
  fi
fi

if [[ "${DEPLOY_RPC}" == "yes" ]]; then
  # Begin the RPC installation
  bash ${BASE_DIR}/scripts/deploy-rpc-playbooks.sh
fi
