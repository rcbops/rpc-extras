Ansible HAProxy Role
##########################
:tags: rackspace, rpc, cloud, ansible, haproxy
:category: \*nix

Role for the deployment of HAProxy within Rackspace Private Cloud.

.. code-block:: yaml

    - name: Setup haproxy host
      hosts: haproxy_hosts
      user: root
      roles:
        - { role: "haproxy_rpc" }
