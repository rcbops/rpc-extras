Host configuration for Rackspace Private Cloud Support
##############
:tags: rpc, cloud, ansible, support, rackspace
:category: \*nix

Role for configuring hosts for support purposes within Rackspace Private Cloud

This role will install the following:
    * holland backups
    * packages required by support

.. code-block:: yaml

    - name: Setup hosts for rpc-support
      hosts: hosts:all_containers
      user: root
      roles:
        - { role: "rpc_support", tags: [ "rpc-support" ] }
