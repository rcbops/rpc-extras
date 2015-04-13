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

* `elasticsearch.yml` - deploys an elasticsearch host
* `horizon_extensions.yml` - rebrands the horizon dashboard for Rackspace,
as well as adding a Rackspace tab and a Solutions tab, which provides
Heat templates for commonly deployed applications.
* `kibana.yml` - Setup Kibana on the Kibana hosts for the logging dashboard.
* `logstash.yml` - deploys a logstash host
* `rpc-support.yml` - provides holland backup service, support SSH key
distribution, custom security group rules, bashrc settings, and other
miscellaneous tasks helpful to support personnel.
* `setup-maas.yml` - deploys, sets up, and installs Rackspace
[MaaS](http://www.rackspace.com/cloud/monitoring) checks
for Rackspace Private Clouds.
* `setup-logging.yml` - deploys and configures Logstash, Elasticsearch, and 
Kibana to tag, index, and expose aggregated logs from all hosts and containers
in the deployment using the related plays mentioned above..
* `site.yml` - deploys all the above playbooks.

Basic Setup:

1. Clone 
[os-ansible-deployment](https://github.com/stackforge/os-ansible-deployment).
2. Clone [rpc-extras](https://github.com/rcbops/rpc-extras).
3. Prepare the os-ansible-deployment configuration. If you're building an AIO
you can simply execute `scripts/bootstrap-aio.sh` from the root of the
os-ansible-deployment clone.
4. From the root of the os-ansible-deployment clone, execute
`scripts/bootstrap-ansible.sh`.
5. Recursively copy `rpc-extras/etc/openstack_deploy/*` to
`/etc/openstack_deploy/`.
6. Set the `rpc_repo_path` in
`/etc/openstack_deploy/user_extras_variables.yml` to the path of the
`os-ansible-deployment` repository clone directory.
7. Set all other variables in
`/etc/openstack_deploy/user_extras_variables.yml` appropriately.
7. Edit `rpc-extras/playbooks/ansible.cfg` and ensure the paths to the roles, playbooks and
inventory are correct.
9. Generate the random passwords for the extras by executing
`scripts/pw-token-gen.py --file
/etc/openstack_deploy/user_extras_secrets.yml` from the
`os-ansible-deployment` clone directory.
10. Change to the `os-ansible-deployment/playbooks` directory and execute the
plays. You can optionally execute `scripts/run-playbooks.sh` from the root of
os-ansible-deployment clone.
11. Change to the `rpc-extras/playbooks` directory and execute your
desired plays.  IE:

```bash
openstack-ansible site.yml
```

# Ansible Roles

* `elasticsearch`
* `horizon_extensions`
* `kibana`
* `logstash`
* `rpc_maas`
* `rpc_support`
