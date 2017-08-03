#!/usr/bin/env bash

set -e -u -x
set -o pipefail

source ${BASE_DIR}/scripts/functions.sh

# begin the RPC installation
cd ${RPCD_DIR}/playbooks/

# configure everything for RPC support access
if [[ "${DEPLOY_SUPPORT_ROLE}" == "yes" ]]; then
    run_ansible rpc-support.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
    run_ansible setup-logging.yml
fi

# Download the latest release of rpc-maas
# TODO(odyssey4me):
# Remove this once rpc-gating no longer tries
# to run rpc-maas as its own thing and instead
# just uses deploy.sh end-to-end. This line
# should not be necessary as setup-maas.yml
# below includes maas-get.yml
run_ansible maas-get.yml

# Deploy and configure RAX MaaS
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
    # Run the rpc-maas setup process
    run_ansible setup-maas.yml

    # verify RAX MaaS is running after all necessary
    # playbooks have been run
    run_ansible verify-maas.yml
fi

# To send data to the influxdb server, we need to deploy and
# configure telegraf.
# By default, telegraf will use log_hosts (rsyslog hosts)
# to define its influxdb servers.
# These playbooks need maas-get to have run previously.
if [[ "${DEPLOY_TELEGRAF}" == "yes" ]]; then
    # BUILD_TAG is used as reference for gating, to allow
    if [[ -z "${BUILD_TAG}" ]]; then
        # user_zzz_variables are generated at every build, so
        # we are fine to just echo it.
        echo 'maas_job_reference: "${BUILD_TAG}"' >> /etc/openstack_deploy/user_zzz_gating_metrics_variables.yml
        # Telegraph shipping is done to influx nodes belonging to
        # influx_telegraf_targets | union(influx_all)
        if [[ -z "${INFLUX_IP}" ]]; then
            cat >> /etc/openstack_deploy/user_zzz_gating_metrics_variables.yml << EOF
influx_telegraf_targets:
  - 'http://$INFLUX_IP:$INFLUX_PORT'
EOF
        fi
    fi
    run_ansible /opt/rpc-maas/playbooks/maas-tigkstack-telegraf.yml
fi

# Deploy Influx
if [[ "${DEPLOY_INFLUX}" == "yes" ]]; then
    # We'll assume the deployer has configured his environment
    # to define the influx_all servers.
    run_ansible /opt/rpc-maas/playbooks/maas-tigkstack-influxdb.yml
fi