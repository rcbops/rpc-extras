#!/usr/bin/env bash

set -e -u -x
set -o pipefail
source /opt/rpc-extras/os-ansible-deployment/scripts/scripts-library.sh

export RPCD_LOGGING=${RPCD_LOGGING:-"FALSE"}
export RPCD_AIO=${RPCD_AIO:-"FALSE"}

OSAD_DIR='/opt/rpc-extras/os-ansible-deployment'
RPCD_DIR='/opt/rpc-extras/rpcd'

# setup the things
cd "${OSAD_DIR}"
if [[ "${RPCD_AIO}" == "yes" ]]; then
  if [[ ! -d /etc/openstack_deploy/ ]]; then
    ./scripts/bootstrap-aio.sh
    cp -R "${RPCD_DIR}"/etc/openstack_deploy/* /etc/openstack_deploy/
  fi
fi

# bootstrap ansible only if not installed
which openstack-ansible
if [[ $? -ne 0 ]]; then
  ./scripts/bootstrap-ansible.sh
fi

# only set up the passwords once
grep -E '^kibana_password:$' /etc/openstack_deploy/user_extras_secrets.yml
if [[ $? -ne 0 ]]; then
  ./scripts/pw-token-gen.py --file /etc/openstack_deploy/user_extras_secrets.yml
fi

cd "${OSAD_DIR}"/playbooks/
install_bits setup-hosts.yml
if [[ "${RPCD_AIO}" == "yes" ]]; then
  install_bits haproxy-install.yml
fi
install_bits setup-infrastructure.yml setup-openstack.yml

# setup the rest
cd "${RPCD_DIR}"/playbooks/
install_bits horizon_extensions.yml rpc-support.yml
# maas doesn't work with aio directly
if [[ "${RPCD_AIO}" != "yes" ]]; then
  install_bits setup-maas.yml
fi
if [[ "${RPCD_LOGGING}" == "yes" ]]; then
  install_bits setup-logging.yml
fi
