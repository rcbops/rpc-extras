#!/usr/bin/env bash

set -e -u -x
set -o pipefail

export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_HAPROXY=${DEPLOY_HAPROXY:-"no"}
export DEPLOY_OA=${DEPLOY_OA:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_CEILOMETER=${DEPLOY_CEILOMETER:-"no"}
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}

source /opt/rpc-openstack/openstack-ansible/scripts/scripts-library.sh
OA_DIR='/opt/rpc-openstack/openstack-ansible'
RPCD_DIR='/opt/rpc-openstack/rpcd'
RPCD_VARS='/etc/openstack_deploy/user_extras_variables.yml'
RPCD_SECRETS='/etc/openstack_deploy/user_extras_secrets.yml'

# begin the bootstrap process
cd ${OA_DIR}

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
    sed -i 's/# elasticsearch_heap_size_mb/elasticsearch_heap_size_mb/' $RPCD_VARS
    # set the kibana admin password
    sed -i "s/kibana_password:.*/kibana_password: ${ADMIN_PASSWORD}/" $RPCD_SECRETS
    # set the load balancer name to the host's name
    sed -i "s/lb_name: .*/lb_name: '$(hostname)'/" $RPCD_VARS
    # set the notification_plan to the default for Rackspace Cloud Servers
    sed -i "s/maas_notification_plan: .*/maas_notification_plan: npTechnicalContactsEmail/" $RPCD_VARS
    # set the necessary bits for ceph
    if [[ "$DEPLOY_CEPH" == "yes" ]]; then
      cp -a ${RPCD_DIR}/etc/openstack_deploy/conf.d/ceph.yml.aio /etc/openstack_deploy/conf.d/ceph.yml

      # In production, the OSDs will run on bare metal however in the AIO we'll put them in containers
      # so the MONs think we have 3 OSDs on different hosts.
      sed -i 's/is_metal: true/is_metal: false/' /etc/openstack_deploy/env.d/ceph.yml

      sed -i "s/journal_size:.*/journal_size: 1024/" $RPCD_VARS
      echo "monitor_interface: eth1" | tee -a $RPCD_VARS
      echo "public_network: 172.29.236.0/22" | tee -a $RPCD_VARS
      sed -i "s/raw_multi_journal:.*/raw_multi_journal: false/" $RPCD_VARS
      echo "osd_directory: true" | tee -a $RPCD_VARS
      echo "osd_directories:" | tee -a $RPCD_VARS
      echo "  - /var/lib/ceph/osd/mydir1" | tee -a $RPCD_VARS
      sed -i "s/glance_default_store:.*/glance_default_store: rbd/" /etc/openstack_deploy/user_variables.yml
      echo "nova_libvirt_images_rbd_pool: vms" | tee -a /etc/openstack_deploy/user_variables.yml
      echo "cinder_ceph_client_uuid:"  | tee -a /etc/openstack_deploy/user_secrets.yml
    fi
    # set the ansible inventory hostname to the host's name
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/openstack_user_config.yml
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/conf.d/*.yml
  fi
fi

# bootstrap ansible if need be
which openstack-ansible || ./scripts/bootstrap-ansible.sh

# ensure all needed passwords and tokens are generated
./scripts/pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml
./scripts/pw-token-gen.py --file $RPCD_SECRETS

# Apply any patched files.
cd ${RPCD_DIR}/playbooks
openstack-ansible -i "localhost," patcher.yml

# begin the openstack installation
if [[ "${DEPLOY_OA}" == "yes" ]]; then
  cd ${OA_DIR}/playbooks/

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

  if [[ "$DEPLOY_CEPH" == "yes" ]]; then
    pushd ${RPCD_DIR}/playbooks/
      install_bits ceph-all.yml
    popd
  fi

  # setup the infrastructure
  install_bits setup-infrastructure.yml

  # setup openstack
  install_bits setup-openstack.yml

  if [[ "${DEPLOY_TEMPEST}" == "yes" ]]; then
    # Deploy tempest
    install_bits os-tempest-install.yml
  fi

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
  sleep 30
  install_bits verify-maas.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
  install_bits setup-logging.yml

  # deploy the LB required for the ELK stack
  if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    install_bits haproxy.yml
  fi
fi
