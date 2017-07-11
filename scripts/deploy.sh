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
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_CEILOMETER="no"
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
export DEPLOY_HARDENING=${DEPLOY_HARDENING:-"no"}
export DEPLOY_RPC=${DEPLOY_RPC:-"yes"}
export ANSIBLE_FORCE_COLOR=${ANSIBLE_FORCE_COLOR:-"true"}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
export UNAUTHENTICATED_APT=${UNAUTHENTICATED_APT:-no}

export RPCM_VARIABLES='/etc/openstack_deploy/user_rpcm_variables.yml'

OA_DIR='/opt/rpc-openstack/openstack-ansible'
RPCD_VARS='/etc/openstack_deploy/user_extras_variables.yml'
RPCD_SECRETS='/etc/openstack_deploy/user_extras_secrets.yml'

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

# bootstrap ansible and install galaxy roles (needed whether AIO or multinode)
./scripts/bootstrap-ansible.sh
# This removes Ceph roles downloaded using their pre-Ansible-Galaxy names
ansible-galaxy remove --roles-path /opt/rpc-openstack/rpcd/playbooks/roles/ ceph-common ceph-mon ceph-osd

ansible-galaxy install --role-file=/opt/rpc-openstack/ansible-role-requirements.yml --force \
                           --roles-path=/opt/rpc-openstack/rpcd/playbooks/roles

# Enable playbook callbacks from OSA to display playbook statistics
grep -q callback_plugins playbooks/ansible.cfg || sed -i '/\[defaults\]/a callback_plugins = plugins/callbacks' playbooks/ansible.cfg

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
    # set network speed for vms
    echo "net_max_speed: 1000" >>$RPCD_VARS
    echo "neutron_metadata_checksum_fix: yes" >> /etc/openstack_deploy/user_variables.yml

    # TODO(odyssey4me):
    # This is disabled until work can be done to resolve the upgrade issues.
    # https://github.com/rcbops/rpc-openstack/issues/2258
    sed -i "s/cinder_service_backup_program_enabled: .*/cinder_service_backup_program_enabled: false/" /etc/openstack_deploy/user_variables.yml

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
  # remove swift config if not deploying swift.
  if [[ "$DEPLOY_SWIFT" != "yes" ]]
  then
    rm /etc/openstack_deploy/conf.d/swift.yml
  fi
  rm -f /etc/openstack_deploy/conf.d/aodh.yml
  rm -f /etc/openstack_deploy/conf.d/ceilometer.yml
fi

# Apply host security hardening with openstack-ansible-security
# The is applied as part of setup-hosts.yml
if [[ "$DEPLOY_HARDENING" == "yes" ]]
then
  if grep -q '^apply_security_hardening:' /etc/openstack_deploy/user_variables.yml
  then
    sed -i "s/^apply_security_hardening:.*/apply_security_hardening: true/" /etc/openstack_deploy/user_variables.yml
  else
    echo "apply_security_hardening: true" >> /etc/openstack_deploy/user_variables.yml
  fi
else
  if grep -q '^apply_security_hardening:' /etc/openstack_deploy/user_variables.yml
  then
    sed -i "s/^apply_security_hardening:.*/apply_security_hardening: false/" /etc/openstack_deploy/user_variables.yml
  else
    echo "apply_security_hardening: false" >> /etc/openstack_deploy/user_variables.yml
  fi
fi

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

  # This deploy script is also used for minor upgrades (within an openstack release)
  # Some versions of liberty deploy pip lockdown to the repo server, in order for an
  # upgrade to succeed the pip config must be removed so that repo builds have
  # access to external repos.
  # Issue tracking upstream fix: https://github.com/rcbops/rpc-openstack/issues/1028
  ansible repo_all -m file -a 'name=/root/.pip state=absent' 2>/dev/null ||:

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

  # We have to skip V-38462 when using an unauthenticated mirror
  # V-38660 is skipped for compatibility with Ubuntu Xenial
  if [[ ${UNAUTHENTICATED_APT} == "yes" && ${DEPLOY_HARDENING} == "yes" ]]; then
    run_ansible setup-hosts.yml --skip-tags=V-38462,V-38660
  else
    run_ansible setup-hosts.yml
  fi

  # ensure correct pip.conf
  pushd ${RPCD_DIR}/playbooks/
    run_ansible pip-lockdown.yml
  popd

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

function run_lock {
  set +e
  run_item="${RUN_TASKS[$1]}"
  file_part="${run_item}"

  for part in $run_item; do
    if [[ "$part" == *.yml ]];then
      file_part="$part"
      break
    fi
  done

  if [ ! -d  "/etc/openstack_deploy/upgrade-liberty" ]; then
      mkdir -p "/etc/openstack_deploy/upgrade-liberty"
  fi

  upgrade_marker_file=$(basename ${file_part} .yml)
  upgrade_marker="/etc/openstack_deploy/upgrade-liberty/$upgrade_marker_file.complete"

  if [ ! -f "$upgrade_marker" ];then
    # note(sigmavirus24): use eval so that we properly turn strings like
    # "/tmp/fix_container_interfaces.yml || true"
    # into a command, otherwise we'll get an error that there's no playbook
    # named ||
    eval "openstack-ansible $2"
    playbook_status="$?"
    echo "ran $run_item"

    if [ "$playbook_status" == "0" ];then
      RUN_TASKS=("${RUN_TASKS[@]/$run_item}")
      touch "$upgrade_marker"
      echo "$run_item has been marked as success"
    else
      echo "******************** failure ********************"
      echo "The upgrade script has encountered a failure."
      echo "Failed on task \"$run_item\""
      echo "Re-run the deploy.sh script, or"
      echo "execute the remaining tasks manually:"
      # NOTE:
      # List the remaining, incompleted tasks from the tasks array.
      # Using seq to genertate a sequence which starts from the spot
      # where previous exception or failures happened.
      # run the tasks in order
      for item in $(seq $1 $((${#RUN_TASKS[@]} - 1))); do
        if [ -n "${RUN_TASKS[$item]}" ]; then
          echo "openstack-ansible ${RUN_TASKS[$item]}"
        fi
      done
      echo "******************** failure ********************"
      exit 99
    fi
  else
    RUN_TASKS=("${RUN_TASKS[@]/$run_item.*}")
  fi
  set -e
}


if [[ "${DEPLOY_RPC}" == "yes" ]]; then
  pushd  ${RPCD_DIR}/playbooks

  # configure everything for RPC support access
    export DEPLOY_SUPPORT_ROLE="yes"

  # begin the RPC installation
    bash ${BASE_DIR}/scripts/deploy-rpc-playbooks.sh

  # configure the horizon extensions
    RUN_TASKS+=("horizon_extensions.yml")

  # deploy and configure the ELK stack
    if [[ "${DEPLOY_ELK}" == "yes" ]]; then

    # deploy the LB required for the ELK stack
      if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
        RUN_TASKS+=(" haproxy.yml")
      fi
    fi

    for item in ${!RUN_TASKS[@]}; do
      run_lock $item "${RUN_TASKS[$item]}"
    done

  popd
fi
