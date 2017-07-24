# Ironic Configuration

This document will guide you through the necessary steps to properly configure
and setup Ironic in RPC-O.

## openstack_user_config

### New networks

There are new networks that need to be defined for ironic's use.

	cidr_networks:
	  tftp: <IP network>/<netmask>
	  ironic-ipmi: <IP network>/<netmask>

The `` tftp `` network is the base network for ironic hosts, that being those
hosts that will be bootable and available to end users.  This network contains
both the interfaces used to provision the host via tftp and the way that the
ironic hosts will be able to connect to the outside world (default route).

The `` ironic-ipmi `` network is the network that touches the ipmi devices
(drac, ilo or other) of the ironic hosts.  It allows ironic-conductor to
control the power status of the ironic hosts.

Be sure to add used IPs from these networks to the `` used_ips `` list.

### global\_overrides

There will be two new networks added to the `` provider_networks `` section.

	- network:
	    container_bridge: "br-ironic-ipmi"
	    container_type: "veth"
	    container_interface: "eth_ipmi"
	    ip_from_q: "ironic-ipmi"
	    type: "raw"
	    group_binds:
	      - ironic-infra_hosts

This network connects the `` ironic-ipmi `` network to the ironic-conductor
containers.


	- network:
	    container_bridge: "br-tftp"
	    container_type: "veth"
	    container_interface: "eth_tftp"
	    ip_from_q: "ironic-ipmi"
	    type: "flat"
	    net_name: "tftp"
	    ip_from_q: "tftp"
	    group_binds:
	      - neutron_linuxbridge_agent
	      - ironic_all

This network connects both neutron and all ironic containers to the base
network of the ironic nodes.  Neutron needs to be connected as it controls the
ip assignment of ironic, along with possibly providing gateway access.  Ironic
itself needs access to provision the nodes.

### defining host groups

	ironic-compute_hosts:
	  infra01:
	    ip: <infra01_management_ip>
	  infra02:
	    ip: <infra02_management_ip>
	  infra03:
	    ip: <infra03_management_ip>
	ironic-infra_hosts:
	  infra01:
	    ip: <infra01_management_ip>
	  infra02:
	    ip: <infra02_management_ip>
	  infra03:
	    ip: <infra02_management_ip>

By default if ironic-compute\_hosts and ironic-infra\_hosts are not defined
they will not be deployed.  It is currently recommended to put these containers
on the infrastructure hosts.

## Variable Overrides

### Set up ironic endpoints for Swift/Ironic health checks

The ironic agent needs to be on the ironic-tftp network in order to access
ironic-api and Swift.

The following variables need to be inserted and upated with the correct values
inside of `` user_osa_variables_overrides.yml ``.

	extra_lb_vip_addresses: 
	  - <IP address>
	ironic_openstack_api_url: "<IP address>:{{ ironic_service_port }}"
	ironic_swift_endpoint: "<IP address>:8080" 

The IP addresses referenced should be the same one referenced in
`` extra_lb_vip_addresses `` that have been setup during installation.

### Configure neutron DHCP to be non-authoritative

To prevent us from having conflicts with an existing authoritative DHCP server,
neutron needs to be set to non-authoritative.

In order to do this, a few variables need to be set, so we need to include the
following variables in `` user_osa_variables_overrides.yml ``:

        neutron_dhcp_config:
          dhcp-option-force: "26,1500"
          dhcp-ignore: "tag:!known"
          log-facility: "/var/log/neutron/dnsmasq.log"

## Post deployment setup of neturon

Ironic / OpenStack needs to be deployed before you can finish the configuration
of Ironic.  Once the initial deployment is done, you can proceed.

### Set up the neutron network and configure the cleaning network

	neutron net-create --shared --provider:physical_network tftp --provider:network_type flat tftp
	neutron subnet-create --name ironic-tftp \
	  --allocation-pool start=<NON_ALLOCATED_TFTP_RANGE_START>,end=<NON_ALLOCATED_TFTP_RANGE_END> \
	  --dns-nameserver=4.4.4.4 tftp <TFTP_NETWORK>/<TFTP_NETMASK>

Once the network is created, take the output of 
`` neutron net-list | grep tftp | awk '{print $2}' `` and add the following
section to your `` user_osa_variables_overrides.yml ``.

	ironic_ironic_conf_overrides:
	  neutron:
	    cleaning_network_uuid: "<NEUTRON_TFTP_NETWORK_UUID>"
	  conductor:
	    automated_clean: true

This will autoclean the nodes on checkin and when they are initially registered
to Ironic.

### Redeploy Ironic

Rerun the `` os-ironic-install.yml `` play to get the new settings in place.

## todo: Post deployment image registration and node enrollment
