Ansible Logstash Role
##########################
:tags: rackspace, rpc, cloud, ansible, logstash
:category: \*nix

Role for the deployment of Logstash within Rackspace Private Cloud.

.. code-block:: yaml

    - name: Setup Logstash host
      hosts: logstash_all
      user: root
      roles:
        - { role: "logstash" }
