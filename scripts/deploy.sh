#!/usr/bin/env bash

set -e -u -x
set -o pipefail

## Functions -----------------------------------------------------------------
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_HAPROXY=${DEPLOY_HAPROXY:-"no"}
export DEPLOY_OA=${DEPLOY_OA:-"yes"}
export DEPLOY_RPC=${DEPLOY_RPC:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_CEILOMETER=${DEPLOY_CEILOMETER:-"no"}
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
export ANSIBLE_ROLE_FILE="/opt/rpc-openstack/ansible-role-requirements.yml"
export RPCM_VARIABLES='/etc/openstack_deploy/user_rpcm_variables.yml'

OA_DIR='/opt/rpc-openstack/openstack-ansible'
RPCD_VARS='/etc/openstack_deploy/user_extras_variables.yml'
RPCD_SECRETS='/etc/openstack_deploy/user_extras_secrets.yml'

function run_ansible {
  openstack-ansible ${ANSIBLE_PARAMETERS} --forks ${FORKS} $@
}

# begin the bootstrap process
cd ${OA_DIR}

# bootstrap the AIO
if [[ "${DEPLOY_AIO}" == "yes" ]]; then
 # Determine the largest secondary disk device available for repartitioning
  DATA_DISK_DEVICE=$(lsblk -brndo NAME,TYPE,RO,SIZE | \
                     awk '/d[b-z]+ disk 0/{ if ($4>m){m=$4; d=$1}}; END{print d}')

  # Only set the secondary disk device option if there is one
  if [ -n "${DATA_DISK_DEVICE}" ]; then
    export BOOTSTRAP_OPTS="${BOOTSTRAP_OPTS} bootstrap_host_data_disk_device=${DATA_DISK_DEVICE}"
  fi
  # force the deployment of haproxy for an AIO
  export DEPLOY_HAPROXY="yes"
  if [[ ! -d /etc/openstack_deploy/ ]]; then
    ./scripts/bootstrap-ansible.sh
    ./scripts/bootstrap-aio.sh
    pushd ${RPCD_DIR}
      for filename in $(find etc/openstack_deploy/ -type f -iname '*.yml'); do
        if [[ ! -a "/${filename}" ]]; then
          cp "${filename}" "/${filename}";
        fi
        ../scripts/update-yaml.py "/${filename}" "${filename}";
      done
    popd

    add_config all
    if [[ "${TARGET:-}" == "aio" ]]; then
      add_config aio
    fi
    if [[ "${TRIGGER:-}" == "pr" ]]; then
      add_config pr
    fi

    # ensure that the elasticsearch JVM heap size is limited
    sed -i 's/# elasticsearch_heap_size_mb/elasticsearch_heap_size_mb/' $RPCD_VARS
    # set the kibana admin password
    sed -i "s/kibana_password:.*/kibana_password: ${ADMIN_PASSWORD}/" $RPCD_SECRETS
    # set the load balancer name to the host's name
    sed -i "s/lb_name: .*/lb_name: '$(hostname)'/" $RPCD_VARS
    # set the notification_plan to the default for Rackspace Cloud Servers
    sed -i "s/maas_notification_plan: .*/maas_notification_plan: npTechnicalContactsEmail/" $RPCD_VARS
    # the AIO needs this enabled to test the feature, but $RPCD_VARS defaults this to false
    sed -i "s/cinder_service_backup_program_enabled: .*/cinder_service_backup_program_enabled: true/" /etc/openstack_deploy/user_variables.yml
    # set network speed for vms
    echo "net_max_speed: 1000" >>$RPCD_VARS
    echo "neutron_metadata_checksum_fix: yes" >> /etc/openstack_deploy/user_variables.yml

    # set the necessary bits for ceph
    if [[ "$DEPLOY_CEPH" == "yes" ]]; then
      cp -a ${RPCD_DIR}/etc/openstack_deploy/conf.d/ceph.yml.aio /etc/openstack_deploy/conf.d/ceph.yml

      # In production, the OSDs will run on bare metal however in the AIO we'll put them in containers
      # so the MONs think we have 3 OSDs on different hosts.
      sed -i 's/is_metal: true/is_metal: false/' /etc/openstack_deploy/env.d/ceph.yml
      sed -i "s/journal_size:.*/journal_size: 1024/" $RPCD_VARS
      sed -i "s/raw_multi_journal:.*/raw_multi_journal: false/" $RPCD_VARS
      sed -i "s/glance_default_store:.*/glance_default_store: rbd/" /etc/openstack_deploy/user_variables.yml
      add_config ceph
    else
      if [[ "$DEPLOY_SWIFT" == "yes" ]]; then
        echo "glance_default_store: swift" | tee -a /etc/openstack_deploy/user_osa_variables_defaults.yml
      else
        echo "glance_default_store: file" | tee -a /etc/openstack_deploy/user_osa_variables_defaults.yml
      fi
    fi
    # set the ansible inventory hostname to the host's name
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/openstack_user_config.yml
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/conf.d/*.yml
  fi
  # remove swift config if not deploying swift.
  if [[ "$DEPLOY_SWIFT" != "yes" ]]
  then
    rm /etc/openstack_deploy/conf.d/swift.yml
  fi
  if [ "${DEPLOY_CEILOMETER}" != "yes" ]; then
    rm -f /etc/openstack_deploy/conf.d/ceilometer.yml
    sed -i 's/swift_ceilometer_enabled:.*/swift_ceilometer_enabled: False/' /etc/openstack_deploy/user_variables.yml
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

if [[ ! -f "${RPCM_VARIABLES}" ]]; then
  cp "${RPCD_DIR}/etc/openstack_deploy/user_rpcm_variables.yml" "${RPCM_VARIABLES}"
fi

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

  # setup openstack
  run_ansible setup-openstack.yml

  if [[ "${DEPLOY_TEMPEST}" == "yes" ]]; then
    # Deploy tempest
    run_ansible os-tempest-install.yml
  fi

fi

# begin the RPC installation
if [[ "${DEPLOY_RPC}" == "yes" ]]; then
    cd ${RPCD_DIR}/playbooks/
    
    # build the RPC python package repository
    run_ansible repo-build.yml
    
    # configure all hosts and containers to use the RPC python packages
    run_ansible repo-pip-setup.yml

  # configure everything for RPC support access
    export DEPLOY_SUPPORT_ROLE="yes"

  # begin the RPC installation
    bash ${BASE_DIR}/scripts/deploy-rpc-playbooks.sh

    # configure the horizon extensions
    run_ansible horizon_extensions.yml

    if [[ "${DEPLOY_ELK}" == "yes" ]]; then
      # deploy the LB required for the ELK stack
      if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
        run_ansible haproxy.yml
      fi
    fi
fi
