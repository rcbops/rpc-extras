#!/usr/bin/env bash

set -e -u -x
set -o pipefail

source ${BASE_DIR}/scripts/functions.sh

# begin the RPC installation
cd ${RPCD_DIR}/playbooks/

# configure everything for RPC support access
run_ansible rpc-support.yml

# configure the horizon extensions
run_ansible horizon_extensions.yml

# deploy and configure RAX MaaS
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
  run_ansible setup-maas.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
  run_ansible setup-logging.yml

  # deploy the LB required for the ELK stack
  if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    run_ansible haproxy.yml
  fi
fi

# verify RAX MaaS is running after all necessary
# playbooks have been run
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
  run_ansible verify-maas.yml
fi
