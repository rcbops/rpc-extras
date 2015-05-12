Ansible Kibana Role
##########################
:tags: rackspace, rpc, cloud, ansible, kibana
:category: \*nix

Role for the deployment of Kibana within Rackspace Private Cloud.

.. code-block:: yaml

    - name: Setup Kibana host
      hosts: kibana_all
      user: root
      roles:
        - { role: "kibana" }
