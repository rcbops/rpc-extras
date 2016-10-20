Ansible Logstash Role
##########################
:tags: rackspace, rpc, cloud, ansible
:category: \*nix

Role for the configuration of infrastucture within Rackspace Private Cloud.

.. code-block:: yaml

    - name: Configure hosts
      hosts: "{{ host_group|default('hosts') }}"
      user: root
      roles:
        - { role: "rpc_setup_infrastructure" }
