# Ironic Configuration

This document will guide you through the necessary steps to properly configure
and setup Ironic in RPC-O.

## Variable Overrides

### Set up ironic endpoints for Swift/Ironic health checks

The ironic agent needs to be on the ironic-tftp network in order to access
ironic-api and Swift.

The following variables need to be inserted and upated with the correct values
inside of `` user_osa_variables_overrides ``.

	extra_lb_vip_addresses: 
	  - <IP address>
	ironic_openstack_api_url: "<IP address>:{{ ironic_service_port }}"
	ironic_swift_endpoint: "<IP address>:8080" 

The IP addresses referenced should be the same one referenced in
`` extra_lb_vip_addresses `` that have been setup during installation.
