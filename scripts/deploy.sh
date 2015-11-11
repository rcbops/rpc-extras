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
export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-""}

OA_DIR='/opt/rpc-openstack/openstack-ansible'
RPCD_DIR='/opt/rpc-openstack/rpcd'
RPCD_VARS='/etc/openstack_deploy/user_extras_variables.yml'
RPCD_SECRETS='/etc/openstack_deploy/user_extras_secrets.yml'

function run_ansible {
  openstack-ansible ${ANSIBLE_PARAMETERS} --forks ${FORKS} $@
}

apt-get install python-dev -y
curl https://raw.githubusercontent.com/pypa/pip/7.1.2/contrib/get-pip.py -o /opt/get-pip.py
python2 /opt/get-pip.py || python /opt/get-pip.py
pip install --force-reinstall 'ansible===1.9.4'
ansible-playbook -i 'localhost,' /opt/rpc-openstack/rpcd/playbooks/repo-fetcher.yml
ansible-galaxy install --role-file=/opt/rpc-openstack/ansible-role-requirements.yml --ignore-errors --force

# begin the bootstrap process
cd ${OA_DIR}

# bootstrap the AIO
if [[ "${DEPLOY_AIO}" == "yes" ]]; then
  # force the deployment of haproxy for an AIO
  export DEPLOY_HAPROXY="yes"
  if [[ ! -d /etc/openstack_deploy/ ]]; then
    ./scripts/bootstrap-aio.sh
    pushd ${RPCD_DIR}
      for filename in $(find etc/openstack_deploy/ -type f -iname '*.yml'); do
        if [[ ! -a "/${filename}" ]]; then
          cp "${filename}" "/${filename}";
        fi
        ../scripts/update-yaml.py "/${filename}" "${filename}";
      done
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
    run_ansible haproxy-install.yml
  fi

  # setup the hosts and build the basic containers
  run_ansible setup-hosts.yml

  if [[ "$DEPLOY_CEPH" == "yes" ]]; then
    pushd ${RPCD_DIR}/playbooks/
      run_ansible ceph-all.yml
    popd
  fi

  # setup the infrastructure
  run_ansible setup-infrastructure.yml

  # This section is duplicated from OSA/run-playbooks as RPC doesn't currently
  # make use of run-playbooks. (TODO: hughsaunders)
  # When running in an AIO, we need to drop the following iptables rule in any neutron_agent containers
  # to ensure that instances can communicate with the neutron metadata service.
  # This is necessary because in an AIO environment there are no physical interfaces involved in
  # instance -> metadata requests, and this results in the checksums being incorrect.
  if [ "${DEPLOY_AIO}" == "yes" ]; then
    ansible neutron_agent -m command \
                          -a '/sbin/iptables -t mangle -A POSTROUTING -p tcp --sport 80 -j CHECKSUM --checksum-fill'
    ansible neutron_agent -m shell \
                          -a 'DEBIAN_FRONTEND=noninteractive apt-get install iptables-persistent'
  fi

  # setup openstack
  run_ansible setup-openstack.yml

  if [[ "${DEPLOY_TEMPEST}" == "yes" ]]; then
    # Deploy tempest
    run_ansible os-tempest-install.yml
  fi

fi

# begin the RPC installation
cd ${RPCD_DIR}/playbooks/

# build the RPC python package repository
run_ansible repo-build.yml

# configure all hosts and containers to use the RPC python packages
run_ansible repo-pip-setup.yml

# configure everything for RPC support access
run_ansible rpc-support.yml

# configure the horizon extensions
run_ansible horizon_extensions.yml

# deploy and configure RAX MaaS
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
  run_ansible setup-maas.yml
  sleep 30
  run_ansible verify-maas.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
  run_ansible setup-logging.yml

  # deploy the LB required for the ELK stack
  if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    run_ansible haproxy.yml
  fi
fi
