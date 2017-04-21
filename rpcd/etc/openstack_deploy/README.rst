===================
RPCO user variables
===================

Files in ``/etc/openstack_deploy``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``user_osa_variables_defaults.yml``
   This file contains any variables specific to the OpenStack-Ansible
   project that are overridden and become the default values for RPCO
   deployments. This file should not be modified by deployers.

``user_osa_variables_overrides.yml``
   Any OpenStack-Ansible variable that needs to be overridden by the
   deployer can be specified in this file.

``user_rpco_variables_overrides.yml``
   Any RPCO specific variable that needs to be overridden by the
   deployer can be specified in this file.

``user_rpco__secrets.yml``
   This file contains RPCO specific variables that are used as
   passwords, keys, or tokens. These values are populated by running
   the ``pw-token-gen.py`` script in the OpenStack-Ansible
   ``scripts/`` directory. For example:

   .. code-block:: console

      # cd /opt/rpc-openstack/openstack-ansible/scripts && \
        ./pw-token-gen.py --file /etc/openstack_deploy/user_rpco_secrets.yml


Files in ``/etc/openstack_deploy/conf.d/``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``ceph.yml.aio``
   This file contains target host configurations for an AIO ceph
   infrastructure. It defines ceph monitor hosts, OSD hosts, and
   storage hosts for an AIO ceph deployment. For more information, see
   https://pages.github.rackspace.com/rpc-internal/docs-rpc/rpc-install-internal/ch-ceph.html#deploy-ceph.


Files in ``/etc/openstack_deploy/env.d/``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``ceph.yml``
   Defines container groups and service mappings for the ceph software
   components.

``elasticsearch.yml``
   Defines container groups and service mappings for the Elasticsearch
   software components.

``kibana.yml``
   Defines container groups and service mappings for the Kibana
   software components.

``logstash.yml``
   Defines container groups and service mappings for the Logstash
   software components.

For more information about container groups, see
http://docs.openstack.org/project-deploy-guide/openstack-ansible/newton/app-custom-layouts.html.
