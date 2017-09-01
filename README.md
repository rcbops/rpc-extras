# rpc-openstack
Rackspace Private Cloud (RPC)

This should be fun

# OpenStack-Ansible integration

The rpc-openstack repo wraps
[openstack-ansible](https://github.com/openstack/openstack-ansible)
with RPC preferred default settings and additional playbooks and roles
which Rackspace find useful when operating OpenStack.

# Ansible Playbooks

RPCO carries several playbooks that run in additional to the OpenStack-Ansible
playbooks. These playbooks can be found in the rpcd/playbooks directory.

* `elasticsearch.yml` - deploys an elasticsearch host
* `filebeat.yml` - deploys the filebeat log shipper on all hosts
* `kibana.yml` - Setup Kibana on the Kibana hosts for the logging dashboard.
* `logstash.yml` - deploys a logstash host. If this play is used, be sure to
configure in your user variables the necessary values before this play is run
and then rerun the appropriate plays in openstack-ansible after this play
to ensure that rsyslog ships logs to logstash. See steps 2-4 and 3-2
below for more.
* `rpc-support.yml` - provides holland backup service, support SSH key
distribution, custom security group rules, bashrc settings, and other
miscellaneous tasks helpful to support personnel.
* `setup-maas.yml` - deploys, sets up, and installs Rackspace
[MaaS](http://www.rackspace.com/cloud/monitoring) checks
for Rackspace Private Clouds.
* `setup-logging.yml` - deploys and configures Filebeat, Logstash,
Elasticsearch, and Kibana to tag, index, and expose aggregated logs from all
hosts and containers in the deployment using the related plays mentioned
above.
* `verify-maas.yml` - confirms each maas check selected for each host has been
captured server-side, for recording in MaaS and that each check has at least one
alarm configured for it. This playbook can also be used to perform local checks
and ignore remote API checks by specifing ``maas_use_api: False`` in the
``user_rpco_variables_overrides.yml`` file.
* `ceph-all.yml` - Runs the `ceph-mon.yml` and `ceph-osd.yml` playbooks
* `ceph-mon.yml` - Runs the `ceph.ceph-mon` Ansible role, which is an external role
  located at https://github.com/ceph/ansible-ceph-mon to deploy the ceph monitor bits
* `ceph-osd.yml` - Runs the `ceph.ceph-osd` Ansible role, which is an external role
  located at https://github.com/ceph/ansible-ceph-osd to deploy the ceph OSD bits


# Quick Start with an RPCO All-In-One(AIO)

To build an AIO, first clone the RPCO repo:
```
cd /opt && git clone --recursive https://github.com/rcbops/rpc-openstack
```

Set the ``DEPLOY_AIO`` variable:
```
export DEPLOY_AIO='yes'
```

Run the ``deploy.sh`` script. It is recommended to run this script in either
a tmux or screen session. It will take about 90 minutes to complete:
```
cd /opt/rpc-openstack
./scripts/deploy.sh
```

## Deploying MaaS with an AIO
1. Add the following variables to `/etc/openstack_deploy/user_rpco_variables_overrides.yml`:
```
maas_tenant_id: YourTenantID
maas_username: YourUsername
maas_api_key: YourAPIKey
```
2. Run the MaaS setup plays:
 `cd /opt/rpc-openstack/rpcd/playbooks && openstack-ansible setup-maas.yml`
3. Run the MaaS verify play:
 `cd /opt/rpc-openstack/rpcd/playbooks && openstack-ansible verify-maas.yml`
     MaaS Verification _might_ fail if executed within the first few moments after
     the `setup-maas.yml` playbook completes. This is because some of the MaaS checks
     might not have registered to the API yet. If it fails, rerun the playbook after
     a few minutes.

# Basic Setup (non-AIO deployments):

1. Clone the RPC repository:
   `cd /opt && git clone --recursive https://github.com/rcbops/rpc-openstack`
2. Unless doing an AIO build, prepare the openstack-ansible configuration.
  1. recursively copy the OpenStack-Ansible configuration files:
     `cp -R openstack-ansible/etc/openstack_deploy /etc/openstack_deploy`
  2. move OSA variables to the correct locations.

     ```
     rm /etc/openstack_deploy/user_variables.yml  # unused, nothing set
     mv /etc/openstack_deploy/user_secrets.yml /etc/openstack_deploy/user_osa_secrets.yml
     ```
  3. copy the RPC configuration files:
     1. `cp rpcd/etc/openstack_deploy/user_*_defaults.yml /etc/openstack_deploy`
     2. `cp rpcd/etc/openstack_deploy/env.d/* /etc/openstack_deploy/env.d`
  4. If the ELK stack is not going to be used, remove the container
     configurations from the environment:
     `rm -f /etc/openstack_deploy/env.d/{elasticsearch,logstash,kibana}.yml`
  5. Edit configurations in `/etc/openstack_deploy` for example:
    1. `openstack_user_config.yml.example` or
       `openstack_user_config.yml.aio`
    2. There is a tool to generate the inventory for RAX datacenters, otherwise
       it will need to be coded by hand.
3. Run the RPC deploy script: `cd /opt/rpc-openstack && ./scripts/deploy.sh`
  1. If building without the ELK stack, set `DEPLOY_ELK=no` before running

# Environment Variables for deploy.sh


Use these environment variables to override aspects of `deploy.sh`'s behavior.

Variable           | Default                            | Description                                          | Notes
-------------------|------------------------------------|------------------------------------------------------|------------------------------------------------------------------
ADMIN_PASSWORD     | secrete                            | Set Admin password for Kibana                        | Only used if DEPLOY_AIO=yes
DEPLOY_AIO         | no                                 | Deploy All-In-One (AIO)                              | Overrides DEPLOY_HAPROXY=yes
DEPLOY_OA          | yes                                | Deploy OpenStack-Ansible (OA)                        |
DEPLOY_ELK         | yes                                | Deploy Logging Stack (ELK)                           | Only used if DEPLOY_OA=yes
DEPLOY_MAAS        | no                                 | Deploy Monitoring (MaaS)                             |
DEPLOY_TEMPEST     | no                                 | Deploy Tempest                                       | Only used if DEPLOY_OA=yes
DEPLOY_RALLY       | no                                 | Deploy Rally                                         | Only used if DEPLOY_OA=yes
DEPLOY_CEPH        | no                                 | Deploy Ceph                                          | Only used if DEPLOY_OA=yes
DEPLOY_SWIFT       | yes                                | Deploy swift                                         |
DEPLOY_HARDENING   | yes                                | Deploy openstack-ansible-security role               |
DEPLOY_RPC         | yes                                | Deploy the RPCO specific variables                   |
BOOTSTRAP_OPTS     |                                    | Any options used for the bootstrap process           | Only used if DEPLOY_AIO=yes
ANSIBLE_PARAMETERS |                                    | Additional paramters passed to Ansible               |

All of the variables for deploy.sh are made available by sourcing the [functions.sh](https://github.com/rcbops/rpc-openstack/blob/master/scripts/functions.sh) script

# Linting

If you would like to lint against a version of ansible that is not the
default, set the `ANSIBLE_VERSION` environment variable to the proper pip
version specification:

```
ANSIBLE_VERSION='>=2.0' tox -e ansible-lint
```

# Gating
Please see the documentation in [rpc-gating/README.md](https://github.com/rcbops/rpc-gating/blob/master/README.md)

# Testing
Please see [Testing](Testing.md) for an overview of RPCO testing.
