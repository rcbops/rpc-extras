# RPC-OpenStack

Rackspace Private Cloud (RPC-OpenStack)

----

### OpenStack-Ansible integration

This repository installs
[openstack-ansible](https://github.com/openstack/openstack-ansible)
and provides for additional RPC-OpenStack value-added software.

#### Quick Start with an RPC-OpenStack All-In-One(AIO)

Clone the RPC-OpenStack repository:

``` shell
git clone https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
```

Run the ``deploy.sh`` script. It is recommended to run this script in either
a tmux or screen session. It will take about 90 minutes to complete:

``` shell
cd /opt/rpc-openstack
DEPLOY_AIO=true OSA_RELEASE="stable/pike" ./scripts/deploy.sh
```

#### Basic Overview (non-AIO deployments):

Clone the RPC-OpenStack repository:

``` shell
git clone https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
```

Run the deploy.sh script to perform a basic Installation.

``` shell
cd /opt/rpc-openstack
OSA_RELEASE="stable/pike" ./scripts/deploy.sh
```

To configure the installation please refer to the upstream OpenStack-Ansible
documentation regarding basic [system setup](https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/configure.html).

Prior to running the playbooks ensure your system(s) are using the latest
artifacts. To ensure all hosts have the same artifacts run the RPC-OpenStack
playbook `site-artifacts.yml`.

Once the deploy configuration has been completed please refer to the
OpenStack-Ansible documentation regarding [running the playbooks](https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/run-playbooks.html).

Upon completion of the deployment run `scripts/deploy-rpco.sh` script to
apply the RPC-OpenStack value added services; you may also run the playbooks
`site-logging.yml` to accomplish much of the same things.

### Gating

Please see the documentation in [rpc-gating/README.md](https://github.com/rcbops/rpc-gating/blob/master/README.md)

