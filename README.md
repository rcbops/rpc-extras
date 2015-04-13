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

* `horizon_extensions.yml` - rebrands the horizon dashboard for Rackspace,
as well as adding a Rackspace tab and a Solutions tab, which provides
Heat templates for commonly deployed applications.
* `logstash.yml` - deploys a logstash host
* `rpc-support.yml` - provides holland backup service, support SSH key
distribution, custom security group rules, bashrc settings, and other
miscellaneous tasks helpful to support personnel.
* `setup-maas.yml` - deploys, sets up, and installs Rackspace
[MaaS](http://www.rackspace.com/cloud/monitoring) checks
for Rackspace Private Clouds.
* `site.yml` - deploys all the above playbooks.

Basic Setup:

1. Complete an installation of
[os-ansible-deployment](https://github.com/stackforge/os-ansible-deployment)
as per the standard mechanism described there.
2. Clone this repository.
3. Recursively copy `rpc-extras/etc/openstack_deploy/*` to
`/etc/openstack_deploy/`.
4. Set the `rpc_repo_path` in
`/etc/openstack_deploy/user_extras_variables.yml` to the path of the
`os-ansible-deployment` repository clone directory.
5. Edit `playbooks/ansible.cfg` and ensure the paths to the roles, playbooks and
inventory are correct.
6. Set all other variables in
`/etc/openstack_deploy/user_extras_variables.yml` appropriately.
7. Generate the random passwords for the extras by executing
`scripts/pw-token-gen.py --file
/etc/openstack_deploy/user_extras_secrets.yml` from the
`os-ansible-deployment` clone directory.
8. Change to the `rpc-extras/playbooks/` directory and execute your
desired plays.  IE:

```bash
openstack-ansible setup-everything.yml
```

# Ansible Roles

* `horizon_extensions`
* `logstash`
* `module_import`
* `rpc_maas`
* `rpc_support`
