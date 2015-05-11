Ansible Beaver Role
###################
:tags: rackspace, rpc, cloud, ansible, beaver
:category: \*nix

Role for the deployment of Beaver within Rackspace Private Cloud.

.. code-block:: yaml

    - name: Setup beaver log shipper
      hosts: all
      user: root
      roles:
        - { role: "beaver" }
