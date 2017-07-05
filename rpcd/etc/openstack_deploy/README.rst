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

Files in ``/etc/openstack_deploy/env.d/``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``elasticsearch.yml``
   Defines container groups and service mappings for the Elasticsearch
   software components.

``kibana.yml``
   Defines container groups and service mappings for the Kibana
   software components.

``logstash.yml``
   Defines container groups and service mappings for the Logstash
   software components.

``nova.yml``
   This file is copied to ``/etc/openstack\_deploy/`` and overrides
   the service mappings for the ``nova_compute_container`` group. This
   is due to the way OSA creates these group/service mappings to
   account for the openvswitch service. Because RPCO does not support
   openvswitch, this group/service mapping must be overridden so that
   the neutron agent containers do not get associated with the
   ``nova_compute_container`` group. For information, see
   https://bugs.launchpad.net/openstack-ansible/+bug/1645979.

For more information about container groups, see
http://docs.openstack.org/project-deploy-guide/openstack-ansible/newton/app-custom-layouts.html.
