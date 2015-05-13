Host configuration for CloudRoast suite
#######################################
:tags: rpc, cloud, ansible, qe, rackspace
:category: \*nix

Role for installing and configuring hosts for quality engineering purposes within Rackspace Private Cloud

This role will install the following:
    * OpenCafe
    * CloudCafe
    * CloudRoast

.. code-block:: yaml

    - name: Installation and setup of CloudRoast suite
      hosts: utility_all
      max_fail_percentage: 20
      user: root
      roles:
        - { role: "cloudroast", tags: [ "cloudroast"] }
            - "cloudroast"
