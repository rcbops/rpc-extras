#!/usr/bin/env bash

set -e -u -x
set -o pipefail
source /opt/rpc-openstack/os-ansible-deployment/scripts/scripts-library.sh

export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_HAPROXY=${DEPLOY_HAPROXY:-"no"}
export DEPLOY_OSAD=${DEPLOY_OSAD:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"yes"}

OSAD_DIR='/opt/rpc-openstack/os-ansible-deployment'
RPCD_DIR='/opt/rpc-openstack/rpcd'

# begin the bootstrap process
cd ${OSAD_DIR}

# bootstrap the AIO
if [[ "${DEPLOY_AIO}" == "yes" ]]; then
  # force the deployment of haproxy for an AIO
  export DEPLOY_HAPROXY="yes"
  # disable the deployment of MAAS for an AIO
  export DEPLOY_MAAS="no"
  if [[ ! -d /etc/openstack_deploy/ ]]; then
    ./scripts/bootstrap-aio.sh
    pushd ${RPCD_DIR}
        for i in $(find etc/openstack_deploy/ -type f -iname '*.yml'); do ../scripts/update-yaml.py /$i $i; done
    popd
    # ensure that the elasticsearch JVM heap size is limited
    sed -i 's/# elasticsearch_heap_size_mb/elasticsearch_heap_size_mb/' /etc/openstack_deploy/user_extras_variables.yml
    # set the kibana admin password
    sed -i "s/kibana_password:.*/kibana_password: ${ADMIN_PASSWORD}/" /etc/openstack_deploy/user_extras_secrets.yml
    # set the load balancer name to the host's name
    sed -i "s/lb_name: .*/lb_name: '$(hostname)'/" /etc/openstack_deploy/user_extras_variables.yml
    # set the notification_plan to the default for Rackspace Cloud Servers
    sed -i "s/maas_notification_plan: .*/maas_notification_plan: npTechnicalContactsEmail/" /etc/openstack_deploy/user_extras_variables.yml
    # set the ansible inventory hostname to the host's name
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/openstack_user_config.yml
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/conf.d/*.yml
  fi
fi

# bootstrap ansible if need be
which openstack-ansible || ./scripts/bootstrap-ansible.sh

# ensure all needed passwords and tokens are generated
./scripts/pw-token-gen.py --file /etc/openstack_deploy/user_extras_secrets.yml

# begin the openstack installation
if [[ "${DEPLOY_OSAD}" == "yes" ]]; then
  cd ${OSAD_DIR}/playbooks/

  # ensure that the ELK containers aren't created if they're not
  # going to be used
  if [[ "${DEPLOY_ELK}" != "yes" ]]; then
    rm -f /etc/openstack_deploy/env.d/{elasticsearch,logstash,kibana}.yml
  fi

  # setup the haproxy load balancer
  if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    install_bits haproxy-install.yml
  fi

  # setup the hosts and build the basic containers
  install_bits setup-hosts.yml

  # setup the infrastructure
  install_bits setup-infrastructure.yml

  # setup openstack
  install_bits setup-openstack.yml
fi

# begin the RPC installation
cd ${RPCD_DIR}/playbooks/

# build the RPC python package repository
install_bits repo-build.yml

# configure all hosts and containers to use the RPC python packages
install_bits repo-pip-setup.yml

# configure everything for RPC support access
install_bits rpc-support.yml

# configure the horizon extensions
install_bits horizon_extensions.yml

# deploy and configure RAX MaaS
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
  install_bits setup-maas.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
  install_bits setup-logging.yml

  # deploy the LB required for the ELK stack
  if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    install_bits haproxy.yml
  fi
fi
