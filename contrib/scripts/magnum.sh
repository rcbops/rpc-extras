if [ "$DEPLOY_MAGNUM" == "yes" ]; then

  export OA_DIR=${OA_DIR:-/opt/rpc-openstack/openstack-ansible}
  export CONTRIB_DIR=${CONTRIB_DIR:-/opt/rpc-openstack/contrib}

  if [ `grep -c magnum /etc/openstack_deploy/user_osa_secrets.yml` -eq 0 ]; then
    grep -q magnum_service_password /etc/openstack_deploy/user_osa_secrets.yml || cat >> /etc/openstack_deploy/user_osa_secrets.yml <<'EOF'
magnum_service_password:
magnum_galera_password:
magnum_rabbitmq_password:
magnum_trustee_password:
EOF

    grep -q os_magnum $OA_DIR/ansible-role-requirements.yml || cat >> $OA_DIR/ansible-role-requirements.yml <<'EOF'
- name: os_magnum
  src: https://github.com/rcbops/openstack-ansible-os_magnum.git
  version: 578467da105ceffd0063cf8e5309f2e9d3d42c19
EOF

    #Re-running ansible-galaxy install to include Magnum role
    ansible-galaxy install --role-file=/opt/rpc-openstack/ansible-role-requirements.yml --force \
                               --roles-path=/opt/rpc-openstack/rpcd/playbooks/roles

    #Distribute Magnum configuration files and settings
    grep -q magnum_config_overrides /etc/openstack_deploy/user_osa_variables_defaults.yml || cat >> /etc/openstack_deploy/user_osa_variables_defaults.yml <<'EOF'
# These configuration entries for Keystone configure some settings for Trusts to
# function properly
keystone_keystone_conf_overrides:
resource:
  admin_project_name: '{{ keystone_admin_tenant_name }}'
  admin_project_domain_name: default
# This change to the Heat Policy configuration file allows Magnum to list all
# stacks, regardless of owner.  This does NOT allow Magnum to have Write access
heat_policy_overrides:
"stacks:global_index": "role:admin"
# This configures Magnum to use the MySQL/Galera database to store certificates
magnum_config_overrides:
certificates:
  cert_manager_type: x509keypair
# TODO(chris_hultin):
# Remove this line upon transition to Newton
ansible_service_mgr: "upstart"
haproxy_extra_services:
- service:
    haproxy_service_name: magnum
    haproxy_backend_nodes: "{{ groups['magnum_all'] | default([]) }}"
    haproxy_port: 9511
    haproxy_balance_type: http
    haproxy_balance_alg: leastconn
    haproxy_backend_options:
      - "forwardfor"
      - "httpchk /status"
      - "httplog"
magnum_git_install_branch: stable/newton
magnum_requirements_git_install_branch: stable/newton
magnum_git_install_fragments: "venvwithindex=True&ignorerequirements=True"
magnum_rabbitmq_port: "{{ rabbitmq_port }}"
magnum_rabbitmq_servers: "{{ rabbitmq_servers }}"
magnum_rabbitmq_use_ssl: "{{ rabbitmq_use_ssl }}"
magnum_service_port: 9511
magnum_service_proto: http
magnum_service_publicuri_proto: "{{ openstack_service_adminuri_proto | default(magnum_service_proto) }}"
magnum_service_internaluri_proto: "{{ openstack_service_adminuri_proto | default(magnum_service_proto) }}"
magnum_service_adminuri_proto: "{{ openstack_service_adminuri_proto | default(magnum_service_proto) }}"
magnum_service_user_name: magnum
magnum_service_project_name: service
magnum_service_project_domain_id: default
magnum_service_user_domain_id: default
magnum_service_adminuri: "{{ magnum_service_adminuri_proto }}://{{ internal_lb_vip_address }}:{{ magnum_service_port }}"
magnum_service_adminurl: "{{ magnum_service_adminuri }}"
magnum_service_region: "{{ service_region }}"
magnum_rabbitmq_userid: magnum
magnum_rabbitmq_vhost: /magnum

EOF

    # TODO(chris_hultin):
    # Remove this section upon transition to Newton
    # This is required so that repo_build.yml does not attempt to build a different version of Magnum
    grep -q magnum_git_repo $OA_DIR/playbooks/defaults/repo_packages/openstack_services.yml ||  cat >> $OA_DIR/playbooks/defaults/repo_packages/openstack_services.yml <<'EOF'
magnum_git_repo: https://git.openstack.org/openstack/magnum
magnum_git_install_branch: stable/mitaka
magnum_git_dest: "/opt/magnum_{{ magnum_git_install_branch | replace('/', '_') }}"
EOF

    cp $CONTRIB_DIR/magnum/os-magnum-install.yml $OA_DIR/playbooks/
    cp $CONTRIB_DIR/magnum/magnum.yml /etc/openstack_deploy/env.d/magnum.yml

    grep -q os-magnum-install.yml $OA_DIR/playbooks/setup-openstack.yml || echo "- include: os-magnum-install.yml" >> $OA_DIR/playbooks/setup-openstack.yml
  fi
fi
