#!/usr/bin/env bash

set -e -u -x
source /opt/rpc-extras/os-ansible-deployment/scripts/scripts-library.sh

export RPCD_LOGSTASH=${RPCD_LOGSTASH:-"FALSE"}
export RPCD_AIO=${RPCD_AIO:-"FALSE"}

OSAD_DIR='/opt/rpc-extras/os-ansible-deployment'
RPCD_DIR='/opt/rpc-extras/rpcd'

# setup the things
cd "${OSAD_DIR}"
if [ "${RPCD_AIO}" == "yes" ]; then
  ./scripts/bootstrap-aio.sh
  cp -R "${RPCD_DIR}"/etc/openstack_deploy/* /etc/openstack_deploy/
fi
./scripts/bootstrap-ansible.sh
./scripts/pw-token-gen.py --file /etc/openstack_deploy/user_extras_secrets.yml
cd "${OSAD_DIR}"/playbooks/
install_bits setup-hosts.yml
if [ "${RPCD_AIO}" == "yes" ]; then
  install_bits haproxy-install.yml
fi
install_bits setup-infrastructure.yml setup-openstack.yml

# setup the rest
cd "${RPCD_DIR}"/playbooks/
install_bits horizon_extensions.yml rpc-support.yml setup-maas.yml
if [ "${RPCD_LOGSTASH}" == "yes" ]; then
  install_bits setup-logging.yml
fi
