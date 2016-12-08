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
export DEPLOY_CEILOMETER="no"
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
export DEPLOY_HARDENING=${DEPLOY_HARDENING:-"yes"}
export ANSIBLE_FORCE_COLOR=${ANSIBLE_FORCE_COLOR:-"true"}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
export UNAUTHENTICATED_APT=${UNAUTHENTICATED_APT:-no}

export BASE_DIR='/opt/rpc-openstack'
export OA_DIR='/opt/rpc-openstack/openstack-ansible'
export OA_OVERRIDES='/etc/openstack_deploy/user_osa_variables_overrides.yml'
export RPCD_DIR='/opt/rpc-openstack/rpcd'
export RPCD_OVERRIDES='/etc/openstack_deploy/user_rpco_variables_overrides.yml'
export RPCD_SECRETS='/etc/openstack_deploy/user_rpco_secrets.yml'

source ${BASE_DIR}/scripts/functions.sh

if [[ "$DEPLOY_AIO" != "yes" ]] && [[ "$DEPLOY_HARDENING" != "yes" ]]; then
  echo "** DEPLOY_HARDENING should no longer be used **"
  echo "To disable security hardening, please add the following line to"
  echo "/etc/openstack_deploy/user_osa_variables_overrides.yml and then"
  echo "re-run this script:"
  echo ""
  echo "apply_security_hardening: false"
  exit 1
fi

# Confirm OA_DIR is properly checked out
submodulestatus=$(git submodule status ${OA_DIR})
case "${submodulestatus:0:1}" in
  "-")
    echo "ERROR: rpc-openstack submodule is not properly checked out"
    exit 1
    ;;
  "+")
    echo "WARNING: rpc-openstack submodule does not match the expected SHA"
    ;;
  "U")
    echo "ERROR: rpc-openstack submodule has merge conflicts"
    exit 1
    ;;
esac

# begin the bootstrap process
cd ${OA_DIR}

./scripts/bootstrap-ansible.sh

# This removes Ceph roles downloaded using their pre-Ansible-Galaxy names
ansible-galaxy remove --roles-path /opt/rpc-openstack/rpcd/playbooks/roles/ ceph-common ceph-mon ceph-osd

ansible-galaxy install --role-file=/opt/rpc-openstack/ansible-role-requirements.yml --force \
                           --roles-path=/opt/rpc-openstack/rpcd/playbooks/roles

# bootstrap the AIO
if [[ "${DEPLOY_AIO}" == "yes" ]]; then

  # Get minimum disk size
  DATA_DISK_MIN_SIZE="$((1024**3 * $(awk '/bootstrap_host_data_disk_min_size/{print $2}' ${OA_DIR}/tests/roles/bootstrap-host/defaults/main.yml) ))"
  # Determine the largest secondary disk device available for repartitioning which meets the minimum size requirements
  DATA_DISK_DEVICE=$(lsblk -brndo NAME,TYPE,RO,SIZE | \
                     awk '/d[b-z]+ disk 0/{ if ($4>m && $4>='$DATA_DISK_MIN_SIZE'){m=$4; d=$1}}; END{print d}')
  # Only set the secondary disk device option if there is one
  if [ -n "${DATA_DISK_DEVICE}" ]; then
    export BOOTSTRAP_OPTS="${BOOTSTRAP_OPTS} bootstrap_host_data_disk_device=${DATA_DISK_DEVICE}"
  fi
  # force the deployment of haproxy for an AIO
  export DEPLOY_HAPROXY="yes"
  if [[ ! -d /etc/openstack_deploy/ || ! -d /etc/openstack_deploy/$RPCD_OVERRIDES ]]; then

    # Adding affinity of 3 for rabbit and galera containers
    # This variable is passed as a user variable in the following
    # ansible-playbook command.
    cat > /tmp/openstack_user_config_overrides.yml <<EOF
openstack_user_config_overrides:
  shared-infra_hosts:
    aio1:
      affinity:
        galera_container: 3
        rabbit_mq_container: 3
      ip: 172.29.236.100
EOF
    pushd $OA_DIR/tests
      ansible-playbook bootstrap-aio.yml -i test-inventory.ini -e "${BOOTSTRAP_OPTS:-""}" -e "@/tmp/openstack_user_config_overrides.yml"
    popd

    # Create env.d directory so we can add our own configs
    # See: https://review.openstack.org/#/c/332595/
    mkdir -p /etc/openstack_deploy/env.d

    # move OSA variables file to AIO location.
    mv /etc/openstack_deploy/user_variables.yml /etc/openstack_deploy/user_osa_aio_variables.yml
    pushd ${RPCD_DIR}
      for filename in $(find etc/openstack_deploy/ -type f -iname '*.yml'); do
        if [[ ! -a "/${filename}" ]]; then
          cp "${filename}" "/${filename}";
        fi
      done
    popd
    # ensure that the elasticsearch JVM heap size is limited
    echo "elasticsearch_heap_size_mb: 1024" >> $RPCD_OVERRIDES
    # set the kibana admin password
    sed -i "s/kibana_password:.*/kibana_password: ${ADMIN_PASSWORD}/" $RPCD_SECRETS
    # set the load balancer name to the host's name
    echo "lb_name: '$(hostname)'" >> $RPCD_OVERRIDES
    # set the notification_plan to the default for Rackspace Cloud Servers
    echo "maas_notification_plan: npTechnicalContactsEmail" >> $RPCD_OVERRIDES
    # the AIO needs this enabled to test the feature, but user_rpco_variables_defaults.yml defaults this to false
    echo "cinder_service_backup_program_enabled: true" >> $OA_OVERRIDES
    # set network speed for vms
    echo "net_max_speed: 1000" >> $RPCD_OVERRIDES

    # set the necessary bits for ceph
    if [[ "$DEPLOY_CEPH" == "yes" ]]; then
      cp -a ${RPCD_DIR}/etc/openstack_deploy/conf.d/ceph.yml.aio /etc/openstack_deploy/conf.d/ceph.yml

      # In production, the OSDs will run on bare metal however in the AIO we'll put them in containers
      # so the MONs think we have 3 OSDs on different hosts.
      sed -i 's/is_metal: true/is_metal: false/' /etc/openstack_deploy/env.d/ceph.yml

      echo "journal_size: 1024" >> $RPCD_OVERRIDES
      echo "monitor_interface: eth1" >> $RPCD_OVERRIDES
      echo "public_network: 172.29.236.0/22" >> $RPCD_OVERRIDES
      echo "raw_multi_journal: false" >> $RPCD_OVERRIDES
      echo "osd_directory: true" >> $RPCD_OVERRIDES
      echo "osd_directories:" >> $RPCD_OVERRIDES
      echo "  - /var/lib/ceph/osd/mydir1" >> $RPCD_OVERRIDES
      echo "glance_default_store: rbd" >> $OA_OVERRIDES
      echo "nova_libvirt_images_rbd_pool: vms" >> $OA_OVERRIDES
    else
      if [[ "$DEPLOY_SWIFT" == "yes" ]]; then
        echo "glance_default_store: swift" >> $OA_OVERRIDES
      else
        echo "glance_default_store: file" >> $OA_OVERRIDES
      fi
    fi

    if [[ "$DEPLOY_HARDENING" != "yes" ]]; then
      echo "apply_security_hardening: false" >> $OA_OVERRIDES
    fi

    # set the ansible inventory hostname to the host's name
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/openstack_user_config.yml
    sed -i "s/aio1/$(hostname)/" /etc/openstack_deploy/conf.d/*.yml
  fi
  # remove swift config if not deploying swift.
  if [[ "$DEPLOY_SWIFT" != "yes" ]]; then
    rm /etc/openstack_deploy/conf.d/swift.yml
  fi
  rm -f /etc/openstack_deploy/conf.d/aodh.yml
  rm -f /etc/openstack_deploy/conf.d/ceilometer.yml
  rm -f /etc/openstack_deploy/conf.d/gnocchi.yml

fi

# move OSA secrets to correct locations
if [[ ! -f /etc/openstack_deploy/user_osa_secrets.yml ]] && [[ -f /etc/openstack_deploy/user_secrets.yml ]]; then
  mv /etc/openstack_deploy/user_secrets.yml /etc/openstack_deploy/user_osa_secrets.yml
fi

# update the RPC-O secrets
bash ${BASE_DIR}/scripts/update-secrets.sh

# ensure all needed passwords and tokens are generated
./scripts/pw-token-gen.py --file /etc/openstack_deploy/user_osa_secrets.yml
./scripts/pw-token-gen.py --file $RPCD_SECRETS

# ensure that the ELK containers aren't created if they're not
# going to be used
# NOTE: this needs to happen before ansible/openstack-ansible is first run
if [[ "${DEPLOY_ELK}" != "yes" ]]; then
  rm -f /etc/openstack_deploy/env.d/{elasticsearch,logstash,kibana}.yml
fi

# Apply any patched files.
cd ${RPCD_DIR}/playbooks
openstack-ansible -i "localhost," patcher.yml

# set permissions and lay down overrides files
chmod 0440 /etc/openstack_deploy/user_*_defaults.yml
if [[ ! -f "$OA_OVERRIDES" ]]; then
  cp "${RPCD_DIR}"/etc/openstack_deploy/user_osa_variables_overrides.yml $OA_OVERRIDES
fi
if [[ ! -f "$RPCD_OVERRIDES" ]]; then
  cp "${RPCD_DIR}"/etc/openstack_deploy/user_rpco_variables_overrides.yml $RPCD_OVERRIDES
fi

# begin the openstack installation
if [[ "${DEPLOY_OA}" == "yes" ]]; then

  # This deploy script is also used for minor upgrades (within an openstack release)
  # Some versions of liberty deploy pip lockdown to the repo server, in order for an
  # upgrade to succeed the pip config must be removed so that repo builds have
  # access to external repos.
  # Issue tracking upstream fix: https://github.com/rcbops/rpc-openstack/issues/1028
  ansible repo_all -m file -a 'name=/root/.pip state=absent' 2>/dev/null ||:

  cd ${OA_DIR}/playbooks/

  # setup the haproxy load balancer
  if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    run_ansible haproxy-install.yml
  fi

  # We have to skip V-38462 when using an unauthenticated mirror
  # V-38660 is skipped for compatibility with Ubuntu Xenial
  if [[ ${UNAUTHENTICATED_APT} == "yes" && ${DEPLOY_HARDENING} == "yes" ]]; then
    run_ansible setup-hosts.yml --skip-tags=V-38462,V-38660
  else
    run_ansible setup-hosts.yml
  fi

  if [[ "$DEPLOY_CEPH" == "yes" ]]; then
    pushd ${RPCD_DIR}/playbooks/
      run_ansible ceph-all.yml
    popd
  fi

  # setup the infrastructure
  run_ansible setup-infrastructure.yml

  # This section is duplicated from OSA/run-playbooks as RPC doesn't currently
  # make use of run-playbooks. (TODO: hughsaunders)
  # Note that switching to run-playbooks may inadvertently convert to repo build from repo clone.
  # When running in an AIO, we need to drop the following iptables rule in any neutron_agent containers
  # to ensure that instances can communicate with the neutron metadata service.
  # This is necessary because in an AIO environment there are no physical interfaces involved in
  # instance -> metadata requests, and this results in the checksums being incorrect.
  if [ "${DEPLOY_AIO}" == "yes" ]; then
    ansible neutron_agent -m command \
                          -a '/sbin/iptables -t mangle -A POSTROUTING -p tcp --sport 80 -j CHECKSUM --checksum-fill'
    ansible neutron_agent -m command \
                          -a '/sbin/iptables -t mangle -A POSTROUTING -p tcp --sport 8000 -j CHECKSUM --checksum-fill'
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

# Begin the RPC installation
bash ${BASE_DIR}/scripts/deploy-rpc-playbooks.sh
