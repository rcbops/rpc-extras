Monitoring as a Service (MaaS) for Rackspace Private Cloud
##############
:tags: openstack, rpc, cloud, ansible, maas, rackspace
:category: \*nix

Role for deployment, setup and installation of Rackspace MaaS for Rackspace Private clouds

This role will install the following:
    * raxmon-cli
    * rcbops-maas

.. code-block:: yaml

    - name: Installation and setup of rpc-maas
      hosts: hosts:all_containers
      user: root
      roles:
        - { role: "rpc_maas", tags: [ "rpc-maas" ] }
