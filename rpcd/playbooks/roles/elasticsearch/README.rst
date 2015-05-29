Ansible Elasticsearch Role
##########################
:tags: rackspace, rpc, cloud, ansible, elasticsearch
:category: \*nix

Role for the deployment of Elasticsearch within Rackspace Private Cloud.

.. code-block:: yaml

    - name: Setup elasticsearch host
      hosts: elasticsearch_all
      user: root
      roles:
        - { role: "elasticsearch" }
