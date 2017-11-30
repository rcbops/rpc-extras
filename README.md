# Rackspace Private Cloud - OpenStack

The RPC-OpenStack repository contains additional scripts, variables, and
options for deploying an OpenStack cloud. It is a thin wrapper around the
[OpenStack-Ansible](https://github.com/openstack/openstack-ansible)
deployment framework that is part of the OpenStack namespace.

## Deployment options

There are two different types of RPC-OpenStack deployments available:

* **All-In-One (AIO) Deployment.** An AIO is a quick way to test a
  RPC-OpenStack deployment. All of the cloud's internal services are deployed
  on the same server, which could be a physical server or a virtual machine.

* **Production Deployment.** Production deployments should be done on more
  than one server with at least three nodes available to run the internal
  cloud services.

### All-In-One (AIO) Deployment Quickstart

Clone the RPC-OpenStack repository:

``` shell
git clone https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
```

Start a screen or tmux session (to ensure that the deployment continues even
if the ssh connection is broken) and run `deploy.sh`:

Run the ``deploy.sh`` script within a tmux or screen session:

``` shell
tmux
cd /opt/rpc-openstack
DEPLOY_AIO=true OSA_RELEASE="stable/pike" ./scripts/deploy.sh
```

The `deploy.sh` script will run all of the necessary playbooks to deploy an
AIO cloud and it normally completes in 90 to 120 minutes.

### Production Deployment Guide

Clone the RPC-OpenStack repository:

``` shell
git clone https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
```

Start a screen or tmux session (to ensure that the deployment continues even
if the ssh connection is broken) and run `deploy.sh`:

Run the ``deploy.sh`` script within a tmux or screen session:

``` shell
tmux
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

Post deployment run the **optional** `openstack-image-setup.yml` and
`openstack-flavor-setup.yml` playbooks to setup default flavors and images.

### Testing & Gating

Please see the documentation in [rpc-gating/README.md](https://github.com/rcbops/rpc-gating/blob/master/README.md)
