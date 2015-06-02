# rpc-extras
Optional add-ons for Rackspace Private Cloud

# os-ansible-deploy integration

The rpc-extras repo includes add-ons for the Rackspace Private Cloud product
that integrate with the 
[os-ansible-deployment](https://github.com/stackforge/os-ansible-deployment)
set of Ansible playbooks and roles.
These add-ons extend the 'vanilla' OpenStack environment with value-added
features that Rackspace has found useful, but are not core to deploying an
OpenStack cloud.

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
uncomment the related block in user_extra_variables.yml before this play is
run and then rerun the appropriate plays in os-ansible-deployment after this
play to ensure that rsyslog ships logs to logstash. See steps 11 - 13 below
for more.
* `repo-build.yml` - scans throug the YAML files in the source tree and builds
any packages or git sources into wheels and deploys them to the local repo
server(s).
* `repo-pip-setup.yml` - updates the pip configuration on all of the containers
to include the rpc-extras source that was created by `repo-build.yml`.
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
* `site.yml` - deploys all the above playbooks.

# Basic Setup:

1. Clone the RPC repository:
   `cd /opt && git clone --recursive https://github.com/rcbops/rpc-extras`
2. Unless doing an AIO build, prepare the os-ansible-deployment configuration.
  1. recursively copy the openstack-ansible-deployment configuration files:
     `cp -R os-ansible-deployment/etc/openstack_deploy /etc/openstack_deploy`
  2. recursively copy the RPC configuration files:
     `cp -R rpcd/etc/openstack_deploy /etc/openstack_deploy`
  3. Edit configurations in `/etc/openstack_deploy` for example:
    1. `openstack_user_variables.yml.example` or
       `openstack_user_variables.yml.aio`
    2. There is a tool to generate the inventory for RAX datacenters, otherwise
       it will need to be coded by hand.
3. Run the RPC deploy script: `cd /opt/rpc-extras && ./scripts/deploy.sh`
  1. If building AIO, set `RPCD_AIO=yes` before running
  2. If building without the ELK stack, set `RPCD_LOGGING=no` before running
4. If you want MaaS working with AIO, do the following:
  1. edit `/etc/openstack_deploy/user_extras_variables.yml` to add credentials
  2. run the MaaS setup plays:
     `cd /opt/rpc-extras/rpcd/playbooks && openstack-ansible setup-maas.yml`

# Upgrading

To run an upgrade of an existing os-ansible-deployment installation:

1. Run`scripts/upgrade.sh`.

Please note the following behaviors that are **destructive**:
    * `/etc/rpc_deploy` will be deprecated and the file structure moved to 
      `/etc/openstack_deploy`.
