# rpc-openstack
Optional add-ons for Rackspace Private Cloud

# openstack-ansible integration

The rpc-openstack repo includes add-ons for the Rackspace Private Cloud product
that integrate with the 
[openstack-ansible](https://github.com/openstack/openstack-ansible)
set of Ansible playbooks and roles.
These add-ons extend the 'vanilla' OpenStack environment with value-added
features that Rackspace has found useful, but are not core to deploying an
OpenStack cloud.

# Juno Support

In Juno, the MaaS plugins code is contained in a separate repo,
[rpc-maas](https://github.com/rcbops/rpc-maas), and the Ansible code to deploy
and configure the checks and alarms using these plugins is contained in tree
with the
[openstack-ansible](http://git.openstack.org/cgit/openstack/openstack-ansible/tree/?h=juno)
repo with the Juno branch.

As of Kilo, both the Maas plugins, and the Ansible code to deploy and
configure the checks and alarms, are contained in the
[rpc-openstack](https://github.com/rcbops/rpc-openstack) repo.

The Kilo branch of openstack-ansible does not include any rpc-maas
support directly any longer.

# Ansible Playbooks

Plays:

* `beaver.yml` - deploys the beaver log shipper on all hosts
* `elasticsearch.yml` - deploys an elasticsearch host
* `haproxy` - deploys haproxy configurations for elasticsearch and kibana
* `horizon_extensions.yml` - rebrands the horizon dashboard for Rackspace,
as well as adding a Rackspace tab and a Solutions tab, which provides
Heat templates for commonly deployed applications.
* `kibana.yml` - Setup Kibana on the Kibana hosts for the logging dashboard.
* `logstash.yml` - deploys a logstash host. If this play is used, be sure to
copy the related block in user_rpco_variables_defaults.yml to
user_rpco_variables_overrides before this play is run and then rerun the
appropriate plays in openstack-ansible after this play to ensure that rsyslog
ships logs to logstash. See steps 2-4 and 3-2 below for more.
* `repo-build.yml` - scans throug the YAML files in the source tree and builds
any packages or git sources into wheels and deploys them to the local repo
server(s).
* `repo-pip-setup.yml` - updates the pip configuration on all of the containers
to include the rpc-openstack source that was created by `repo-build.yml`.
* `rpc-support.yml` - provides holland backup service, support SSH key
distribution, custom security group rules, bashrc settings, and other
miscellaneous tasks helpful to support personnel.
* `setup-maas.yml` - deploys, sets up, and installs Rackspace
[MaaS](http://www.rackspace.com/cloud/monitoring) checks
for Rackspace Private Clouds.
* `setup-logging.yml` - deploys and configures Beaver, Logstash,
Elasticsearch, and Kibana to tag, index, and expose aggregated logs from all
hosts and containers in the deployment using the related plays mentioned
above.
* `site.yml` - deploys all the playbooks mentioned here.
* `verify-maas.yml` - confirms each maas check selected for each host has been
captured server-side for recording in MaaS and that each chec has at least one 
alarm configured for it.

# Basic Setup:

1. Clone the RPC repository:
   `cd /opt && git clone --recursive https://github.com/rcbops/rpc-openstack`
2. Unless doing an AIO build, prepare the openstack-ansible configuration.
  1. recursively copy the openstack-ansible-deployment configuration files:
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
  1. If building AIO, set `DEPLOY_AIO=yes` before running
  2. If building without the ELK stack, set `DEPLOY_ELK=no` before running
4. If you want MaaS working with AIO, do the following:
  1. edit `/etc/openstack_deploy/user_rpco_variables_overrides.yml` to add
     credentials
  2. run the MaaS setup plays:
     `cd /opt/rpc-openstack/rpcd/playbooks && openstack-ansible setup-maas.yml`
  3. run the MaaS verify play:
     `cd /opt/rpc-openstack/rpcd/playbooks && openstack-ansible verify-maas.yml`
     MaaS Verification _may_ fail if executed within the first few moments after 
     the Setup plays complete as the MaaS service registers checks and alarms 
     installed on your hosts. If it fails, manually retrying once after a 
     one minute delay is recommended.

# Environment Variables for deploy.sh

Use these environment variables to override aspects of `deploy.sh`'s behavior.

Variable           | Default                            | Description                                          | Notes
-------------------|------------------------------------|------------------------------------------------------|------------------------------------------------------------------
ADMIN_PASSWORD     | secrete                            | Set Admin password for Kibana                        | Only used if DEPLOY_AIO=yes
DEPLOY_AIO         | no                                 | Deploy All-In-One (AIO)                              | Overrides DEPLOY_HAPROXY=yes
DEPLOY_HAPROXY     | no                                 | Deploy HAProxy                                       | Must set DEPLOY_HAPROXY=yes if not using a physical load balancer
DEPLOY_OA          | yes                                | Deploy OpenStack-Ansible (OA)                        |
DEPLOY_ELK         | yes                                | Deploy Logging Stack (ELK)                           | Only used if DEPLOY_OA=yes
DEPLOY_IRONIC      | no                                 | Deploy Ironic                                        | Only used if DEPLOY_AIO=yes
DEPLOY_MAAS        | no                                 | Deploy Monitoring (MaaS)                             |
DEPLOY_TEMPEST     | no                                 | Deploy Tempest                                       | Only used if DEPLOY_OA=yes
DEPLOY_CEILOMETER  | no                                 | Deploy Ceilometer                                    | Not used
DEPLOY_CEPH        | no                                 | Deploy Ceph                                          | Only used if DEPLOY_OA=yes
FORKS              | `grep -c ^processor /proc/cpuinfo` | Number of forks Ansible may use                      | May have issues if FORKS > SSHD's MaxSessions. Adjust accordingly
ANSIBLE_PARAMETERS |                                    | Additional paramters passed to Ansible               |

For instance to adjust the number of forks Ansible is able to use:

```
export FORKS=10
./scripts/deploy.sh
```

# Upgrading

To run an upgrade of an existing openstack-ansible installation:

1. Run`scripts/upgrade.sh`.

Please note the following behaviors that are **destructive**:
    * `/etc/rpc_deploy` will be deprecated and the file structure moved to 
      `/etc/openstack_deploy`.

# Linting

If you would like to lint against a version of ansible that is not the
default, set the `ANSIBLE_VERSION` environment variable to the proper pip
version specification:

```
ANSIBLE_VERSION='>=2.0' tox -e ansible-lint
```
