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
uncomment the related block in user_extra_variables.yml before this play is
run and then rerun the appropriate plays in openstack-ansible after this
play to ensure that rsyslog ships logs to logstash. See steps 11 - 13 below
for more.
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
  2. merge /etc/openstack_deploy/user_variables.yml with rpcd/etc/openstack_deploy/user_variables.yml:

     ```
     scripts/update-yaml.py /etc/openstack_deploy/user_variables.yml rpcd/etc/openstack_deploy/user_variables.yml
     ```
  3. copy the RPC configuration files:
     1. `cp rpcd/etc/openstack_deploy/user_extras_*.yml /etc/openstack_deploy`
     2. `cp rpcd/etc/openstack_deploy/env.d/* /etc/openstack_deploy/env.d`
  4. If the ELK stack is not going to be used, remove the container
     configurations from the environment:
     `rm -f /etc/openstack_deploy/env.d/{elasticsearch,logstash,kibana}.yml`
  5. Edit configurations in `/etc/openstack_deploy` for example:
    1. `openstack_user_variables.yml.example` or
       `openstack_user_variables.yml.aio`
    2. There is a tool to generate the inventory for RAX datacenters, otherwise
       it will need to be coded by hand.
3. Run the RPC deploy script: `cd /opt/rpc-openstack && ./scripts/deploy.sh`
  1. If building AIO, set `DEPLOY_AIO=yes` before running
  2. If building without the ELK stack, set `DEPLOY_ELK=no` before running
4. If you want MaaS working with AIO, do the following:
  1. edit `/etc/openstack_deploy/user_extras_variables.yml` to add credentials
  2. run the MaaS setup plays:
     `cd /opt/rpc-openstack/rpcd/playbooks && openstack-ansible setup-maas.yml`
  3. run the MaaS verify play:
     `cd /opt/rpc-openstack/rpcd/playbooks && openstack-ansible verify-maas.yml`
     MaaS Verification _may_ fail if executed within the first few moments after 
     the Setup plays complete as the MaaS service registers checks and alarms 
     installed on your hosts. If it fails, manually retrying once after a 
     one minute delay is recommended.

# Upgrading

To run an upgrade of an existing openstack-ansible installation:

1. Run`scripts/upgrade.sh`.

Please note the following behaviors that are **destructive**:
    * `/etc/rpc_deploy` will be deprecated and the file structure moved to 
      `/etc/openstack_deploy`.
